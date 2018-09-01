;
; Native support for external interrupts from various I/O devices.
;
; This file contains several interrupt handlers for various logic boards.
; GetExtIntHandler routine will select one of them according to
; InterruptHandlerKind in NKConfigurationInfo.
;
; The primary job of these handlers is to signal the emulator that an external
; interrupt of a specific priority has occurred.
; Due to the fact that the Mac OS primary interrupt handler is resided in the
; legacy 68k code, we need to emulate the 68k interrupt architecture that uses
; seven different interrupt priority levels (IPLs) that aren't present a
; PowerPC CPU.
;
; Fortunately, the 68k IPLs are tied to specific devices/functionality, so it's
; easy to reconstruct them by examining IRQ bits in the I/O controllers.
; For example, all DMA interrupts are handled as if the DMA controller were
; a single device interrupting at level 4.
;
; For the background information, please refer to the Technical Note TN1137.
;

kExternalIntAlign equ 6

########################################################################
; Params:
;    r3 - ptr to NKConfigurationInfo
;
; Returns:
;    r7 - ptr to external interrupt handler for the board we're running on
;
; Spoils:
;    r12

GetExtIntHandler
    mflr    r12         ; save LR
    bl      @tableend
@table
    dc.w    ExternalInt0 - @table           ; 0
    dc.w    ExtIntHandlerPDM - @table       ; 1
    dc.w    ExtIntHandlerTNT - @table       ; 2
    dc.w    ExtIntHandlerPBX - @table       ; 3
    dc.w    ExtIntHandlerCordyceps - @table ; 4
    dc.w    ExtIntHandlerAlchemy - @table   ; 5
    dc.w    ExternalInt6 - @table           ; 6
    align   2
@tableend
    mflr    r7              ; r7 points to @table now
    mtlr    r12             ; restore LR
    lbz     r12, NKConfigurationInfo.InterruptHandlerKind(r3)
    slwi    r12, r12, 1     ; calculate address of the external int handler
    lhzx    r12, r7, r12    ; for InterruptHandlerKind from the offsets
    add     r7, r7, r12     ; in @table and return it in r7
    blr

########################################################################

    _align kExternalIntAlign
ExternalInt0
    mfsprg  r1, 0                           ; Init regs and increment ctr
    dcbz    0, r1
    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    lwz     r2, KDP.NKInfo.ExternalIntCount(r1)
    stw     r3, KDP.r3(r1)
    addi    r2, r2, 1
    stw     r2, KDP.NKInfo.ExternalIntCount(r1)

    mfmsr   r2                              ; Save a self-ptr to FF880000... why?
    lis     r3, 0xFF88
    _ori    r0, r2, MsrDR
    stw     r4, KDP.r4(r1)
    stw     r5, KDP.r5(r1)
    mfsrr0  r4
    mfsrr1  r5
    mtmsr   r0
    isync
    stw     r3, 0(r3)
    mtmsr   r2
    isync
    mtsrr0  r4
    mtsrr1  r5
    lwz     r4, KDP.r4(r1)
    lwz     r5, KDP.r5(r1)

    lwz     r2, KDP.DebugIntPtr(r1)         ; Query the shared mem (debug?) for int num
    mfcr    r0
    lha     r2, 0(r2)
    lwz     r3, KDP.EmuIntLevelPtr(r1)
    rlwinm. r2, r2, 0, 0x80000007
    ori     r2, r2, 0x8000
    sth     r2, 0(r3)
    mfsprg  r2, 2
    lwz     r3, KDP.r3(r1)
    mtlr    r2
    beq     @clear                          ; 0 -> clear interrupt
    bgt     @return                         ; negative -> no interrupt flag
                                            ; positive -> post interrupt

    lwz     r2, KDP.PostIntMask(r1)         ; Post an interrupt via Cond Reg
    or      r0, r0, r2

@return
    mtcr    r0                              ; Set CR and return
    lwz     r0, KDP.r0(r1)
    lwz     r2, KDP.r2(r1)
    mfsprg  r1, 1
    rfi

@clear
    lwz     r2, KDP.ClearIntMask(r1)        ; Clear an interrupt via Cond Reg
    and     r0, r0, r2
    b       @return

########################################################################
; The interrupt handler provided below will be used on the PDM boards
; equipped with the AMIC (Apple Memory mapped I/O Controller) ASIC.
;
; We'll define a mapping between the AMIC IRQ flags
; and the Mac OS 68k interrupt levels as follows:
;
;   IPL 1 <- VIA1 Irq
;   IPL 2 <- VIA2 Irq
;   IPL 3 <- Ethernet MACE
;   IPL 4 <- SCC and DMA for various devices
;   IPL 7 <- NMI (programmer's switch)
;
; AMIC IRQ flags are resided in the byte register at 0x50F2A000 and have
; the following meaning (value 1 indicates IRQ assertion):
;
;   bit 0: pseudo VIA1 IRQ
;   bit 1: pseudo VIA2 IRQ
;   bit 2: Serial SCC IRQ
;   bit 3: Ethernet IRQ
;   bit 4: DMA IRQ
;   bit 5: NMI IRQ


    _align kExternalIntAlign
AMICIrq2IPL ; LUT for AMIC IRQ -> 68k IPL mapping
    dc.b    0, 1, 2, 2, 4, 4, 4, 4
    dc.b    3, 3, 3, 3, 4, 4, 4, 4
    dc.b    4, 4, 4, 4, 4, 4, 4, 4
    dc.b    4, 4, 4, 4, 4, 4, 4, 4
    dc.b    7, 7, 7, 7, 7, 7, 7, 7
    dc.b    7, 7, 7, 7, 7, 7, 7, 7
    dc.b    7, 7, 7, 7, 7, 7, 7, 7
    dc.b    7, 7, 7, 7, 7, 7, 7, 7

    _align kExternalIntAlign
ExtIntHandlerPDM
    mfsprg  r1, 0               ; r1 points to kernel globals
    dcbz    0, r1
    stw     r0, KDP.r0(r1)      ; save r0
    stw     r2, KDP.r2(r1)      ; save r2
    lwz     r2, KDP.NKInfo.ExternalIntCount(r1)
    stw     r3, KDP.r3(r1)      ; save r3
    addi    r2, r2, 1           ; increment external interrupts count
    stw     r2, KDP.NKInfo.ExternalIntCount(r1)

    lis     r2, 0x50F3          ; load base addr of AMIC
    mfmsr   r3                  ; save MSR
    _ori    r0, r3, MsrDR       ; set the DT (data addr translation) bit in MSR
    stw     r4, KDP.r4(r1)      ; save r4
    stw     r5, KDP.r5(r1)      ; save r5
    mfsrr0  r4                  ; save SRR0
    mfsrr1  r5                  ; save SRR1
    mtmsr   r0                  ; enable data address translation
    isync
    li      r0, 0xC0            ; clear AMIC CPU interrupt by setting bits 6-7
    stb     r0, -0x6000(r2)
    eieio
    lbz     r0, -0x6000(r2)     ; read AMIC Irq flags
    mtmsr   r3                  ; disable data address translation
    isync
    mtsrr0  r4                  ; restore SRR0
    mtsrr1  r5                  ; restore SRR1
    lwz     r4, KDP.r4(r1)      ; restore r4
    lwz     r5, KDP.r5(r1)      ; restore r5

    lwz     r3, KDP.CodeBase(r1)        ; r3 points to kernel code page
    rlwimi  r3, r0, 0, 0x0000003F       ; map AMIC IRQ to 68k IPL using LUT
    lbz     r2, AMICIrq2IPL-CodeBase(r3)
    mfcr    r0                          ; clear CR
    lwz     r3, KDP.EmuIntLevelPtr(r1)
    clrlwi. r2, r2, 29
    sth     r2, 0(r3)                   ; store IplValue in EmulatorData
    mfsprg  r2, 2
    lwz     r3, KDP.r3(r1)              ; restore r3
    mtlr    r2
    beq     @clear                      ; 0 -> clear interrupt
                                        ; nonzero -> post interrupt

    lwz     r2, KDP.PostIntMask(r1)     ; Post an interrupt via CR
    or      r0, r0, r2

@return
    mtcr    r0                          ; Set CR
    lwz     r0, KDP.r0(r1)              ; restore r0
    lwz     r2, KDP.r2(r1)              ; restore r1
    mfsprg  r1, 1                       ; and return
    rfi

@clear
    lwz     r2, KDP.ClearIntMask(r1)    ; Clear interrupt flag in CR
    and     r0, r0, r2
    b       @return

########################################################################

    _align kExternalIntAlign
ExtIntHandlerPBX
    mfsprg  r1, 0                           ; Init regs and increment ctr
    dcbz    0, r1
    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    lwz     r2, KDP.NKInfo.ExternalIntCount(r1)
    stw     r3, KDP.r3(r1)
    addi    r2, r2, 1
    stw     r2, KDP.NKInfo.ExternalIntCount(r1)

    lis     r2, 0x50F3                      ; Query OpenPIC at 50F2A000
    mfmsr   r3
    stw     r4, KDP.r4(r1)
    mfsrr0  r4
    stw     r5, KDP.r5(r1)
    mfsrr1  r5
    stw     r6, KDP.r6(r1)
    mfspr   r6, dbat0u
    stw     r7, KDP.r7(r1)
    mfspr   r7, dbat0l

    ori     r0, r2, 3
    mtspr   dbat0u, r0
    ori     r0, r2, 0x2A
    mtspr   dbat0l, r0
    ori     r0, r3, 0x10
    mtmsr   r0
    isync

    lwz     r0, -0x6000(r2)
    ori     r0, r0, 0x80
    stw     r0, -0x6000(r2)
    eieio
    lwz     r0, -0x6000(r2)
    insrwi  r0, r0, 3, 26
    stw     r0, -0x6000(r2)
    eieio
    mr      r2, r0
    mtmsr   r3
    isync

    mtspr   dbat0l, r7
    lwz     r7, KDP.r7(r1)
    mtspr   dbat0u, r6
    lwz     r6, KDP.r6(r1)
    mtsrr1  r5
    lwz     r5, KDP.r5(r1)
    mtsrr0  r4
    lwz     r4, KDP.r4(r1)

    mfcr    r0
    lwz     r3, KDP.EmuIntLevelPtr(r1)
    clrlwi. r2, r2, 29
    ori     r2, r2, 0x8000
    sth     r2, 0(r3)
    mfsprg  r2, 2
    lwz     r3, KDP.r3(r1)
    mtlr    r2
    beq     @clear                          ; 0 -> clear interrupt
                                            ; nonzero -> post interrupt

    lwz     r2, KDP.PostIntMask(r1)         ; Post an interrupt via Cond Reg
    or      r0, r0, r2

@return
    mtcr    r0                              ; Set CR and return
    lwz     r0, KDP.r0(r1)
    lwz     r2, KDP.r2(r1)
    mfsprg  r1, 1
    rfi

@clear
    lwz     r2, KDP.ClearIntMask(r1)        ; Clear an interrupt via Cond Reg
    and     r0, r0, r2
    b       @return

########################################################################
; The Alchemy board uses the same I/O Controller as the TNT board.
; Please refer to ExtIntHandlerTNT for further explanation.

    _align kExternalIntAlign
ExtIntHandlerAlchemy
    mfsprg  r1, 0                           ; Init regs and increment ctr
    dcbz    0, r1
    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    lwz     r2, KDP.NKInfo.ExternalIntCount(r1)
    stw     r3, KDP.r3(r1)
    addi    r2, r2, 1
    stw     r2, KDP.NKInfo.ExternalIntCount(r1)

    lis     r2, 0xF300          ; r3 - base address of GrandCentral
    mfmsr   r0
    _ori    r3, r0, MsrDR
    stw     r4, KDP.r4(r1)
    stw     r5, KDP.r5(r1)
    stw     r6, KDP.r6(r1)
    mfsrr0  r4
    mfsrr1  r5
    mtmsr   r3
    isync
    lis     r3, 0x8000
    li      r6, 0x28
    stwbrx  r3, r6, 2
    eieio
    li      r6, 0x24
    lwbrx   r3, r6, r2
    li      r6, 0x2C
    lwbrx   r6, r6, r2
    and     r3, r6, r3
    eieio
    mtmsr   r0
    isync
    mtsrr0  r4
    mtsrr1  r5
    lwz     r4, KDP.r4(r1)
    lwz     r5, KDP.r5(r1)
    lwz     r6, KDP.r6(r1)

    mfcr    r0
                                ; Interpret GrandCentral IRQ bits:
    rlwinm. r2, r3, 0, 11, 11   ; ExtNMI IRQ asserted?
    li      r2, 7               ; IPL -> 7
    bne     @gotnum

    rlwinm  r2, r3, 0, 15, 16   ; SCC A/B
    rlwimi. r2, r3, 0, 21, 31   ; or any DMA IRQ asserted?
    li      r2, 4               ; IPL -> 4
    bne     @gotnum

    rlwinm. r2, r3, 0, 17, 17   ; MACE IRQ asserted?
    li      r2, 3               ; IPL -> 3
    bne     @gotnum

    andis.  r2, r3, 0x7FEA      ; any other IRQ except VIA1 asserted?
    rlwimi. r2, r3, 0, 18, 19
    li      r2, 2               ; IPL -> 2
    bne     @gotnum

    extrwi. r2, r3, 1, 13       ; bit 13 -> IPL 1 (VIA1)
                                ; else -> IPL 0

@gotnum
    lwz     r3, KDP.EmuIntLevelPtr(r1)
    sth     r2, 0(r3)
    mfsprg  r2, 2
    lwz     r3, KDP.r3(r1)
    mtlr    r2
    beq     @clear                          ; 0 -> clear interrupt
                                            ; nonzero -> post interrupt

    lwz     r2, KDP.PostIntMask(r1)         ; Post an interrupt via Cond Reg
    or      r0, r0, r2

@return
    mtcr    r0                              ; Set CR and return
    lwz     r0, KDP.r0(r1)
    lwz     r2, KDP.r2(r1)
    mfsprg  r1, 1
    rfi

@clear
    lwz     r2, KDP.ClearIntMask(r1)        ; Clear an interrupt via Cond Reg
    and     r0, r0, r2
    b       @return

########################################################################
; This is the handler for external interrupts on the TNT board equipped
; with the GrandCentral I/O Controller ASIC.
; Because GrandCentral is a little-endian device, we'll use the
; byte-reverse load and store instructions to access its registers.

    _align kExternalIntAlign
ExtIntHandlerTNT
    mfsprg  r1, 0                           ; Init regs and increment ctr
    dcbz    0, r1
    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    lwz     r2, KDP.NKInfo.ExternalIntCount(r1)
    stw     r3, KDP.r3(r1)
    addi    r2, r2, 1
    stw     r2, KDP.NKInfo.ExternalIntCount(r1)

    lis     r2, 0xF300          ; r3 - base address of GrandCentral
    mfmsr   r0
    _ori    r3, r0, MsrDR
    stw     r4, KDP.r4(r1)
    stw     r5, KDP.r5(r1)
    stw     r6, KDP.r6(r1)
    mfsrr0  r4
    mfsrr1  r5
    mtmsr   r3                  ; enable data address translation
    isync
    lis     r3, 0x8000
    li      r6, 0x28            ; r6 - offset to interrupt clear register
    stwbrx  r3, r6, r2          ; write byte-reversed ifMode1Clear flag
    eieio
    li      r6, 0x24            ; r6 - offset to interrupt mask register
    lwbrx   r3, r6, r2
    li      r6, 0x2C            ; r6 - offset to interrupt levels register
    lwbrx   r6, r6, r2          ; r3 = READ_LE_DWORD(GC[IntLevels] &
    and     r3, r6, r3          ;      READ_LE_DWORD(GC[IntMask])
    eieio
    mtmsr   r0                  ; disable data address translation
    isync
    mtsrr0  r4
    mtsrr1  r5
    lwz     r4, KDP.r4(r1)
    lwz     r5, KDP.r5(r1)
    lwz     r6, KDP.r6(r1)

    mfcr    r0                  ; reset CR

    rlwinm. r2, r3, 0, 11, 11   ; set IPL to 7
    li      r2, 7               ; if ExtNMI IRQ is asserted
    bne     @gotnum             ;

    rlwinm  r2, r3, 0, 15, 16   ; SCC A and SCC B
    rlwimi. r2, r3, 0, 21, 31   ; together with all DMA IRQs
    li      r2, 4               ; will get the priority level 4
    bne     @gotnum

    rlwinm. r2, r3, 0, 17, 17   ; Ethernet MACE is the only device allowed to
    li      r2, 3               ; interrupt at level 3
    bne     @gotnum

    andis.  r2, r3, 0x7FEA      ; all other devices including SCSI, PCI, Audio,
    rlwimi. r2, r3, 0, 18, 19   ; Floppy etc. except VIA1
    li      r2, 2               ; will get the priority level 2
    bne     @gotnum

    extrwi. r2, r3, 1, 13       ; bit 13 -> IPL 1 (VIA1)
                                ; else -> IPL 0

@gotnum
    lwz     r3, KDP.EmuIntLevelPtr(r1)
    sth     r2, 0(r3)
    mfsprg  r2, 2
    lwz     r3, KDP.r3(r1)
    mtlr    r2
    beq     @clear                          ; 0 -> clear interrupt
                                            ; nonzero -> post interrupt

    lwz     r2, KDP.PostIntMask(r1)         ; Post an interrupt via Cond Reg
    or      r0, r0, r2

@return
    mtcr    r0                              ; Set CR and return
    lwz     r0, KDP.r0(r1)
    lwz     r2, KDP.r2(r1)
    mfsprg  r1, 1
    rfi

@clear
    lwz     r2, KDP.ClearIntMask(r1)        ; Clear an interrupt via Cond Reg
    and     r0, r0, r2
    b       @return

########################################################################

    _align kExternalIntAlign
ExtIntHandlerCordyceps
    mfsprg  r1, 0                           ; Init regs and increment ctr
    dcbz    0, r1
    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    lwz     r2, KDP.NKInfo.ExternalIntCount(r1)
    stw     r3, KDP.r3(r1)
    addi    r2, r2, 1
    stw     r2, KDP.NKInfo.ExternalIntCount(r1)

    lis     r2, 0x5300                      ; Query OpenPIC at 50F2A000
    mfmsr   r3
    stw     r4, KDP.r4(r1)
    mfsrr0  r4
    stw     r5, KDP.r5(r1)
    mfsrr1  r5
    stw     r6, KDP.r6(r1)
    mfspr   r6, dbat0u
    stw     r7, KDP.r7(r1)
    mfspr   r7, dbat0l

    ori     r0, r2, 3
    mtspr   dbat0u, r0
    ori     r0, r2, 0x2A
    mtspr   dbat0l, r0
    sync
    ori     r0, r3, 0x10
    mtmsr   r0
    isync

    lwz     r0, 0x1C(r2)
    sync
    lis     r0, 0
    stw     r0, 0x1C(r2)
    eieio
    lwz     r0, 0x1C(r2)
    lwz     r0, 0x1C(r2)
    sync
    lwz     r2, 0x24(r2)
    sync
    xori    r2, r2, 7
    mtmsr   r3
    isync

    mtspr   dbat0l, r7
    lwz     r7, KDP.r7(r1)
    mtspr   dbat0u, r6
    lwz     r6, KDP.r6(r1)
    mtsrr1  r5
    lwz     r5, KDP.r5(r1)
    mtsrr0  r4
    lwz     r4, KDP.r4(r1)

    mfcr    r0
    lwz     r3, KDP.EmuIntLevelPtr(r1)
    clrlwi. r2, r2, 29
    sth     r2, 0(r3)
    mfsprg  r2, 2
    lwz     r3, KDP.r3(r1)
    mtlr    r2
    beq     @clear                          ; 0 -> clear interrupt
                                            ; nonzero -> post interrupt

    lwz     r2, KDP.PostIntMask(r1)         ; Post an interrupt via Cond Reg
    or      r0, r0, r2

@return
    mtcr    r0                              ; Set CR and return
    lwz     r0, KDP.r0(r1)
    lwz     r2, KDP.r2(r1)
    mfsprg  r1, 1
    rfi

@clear
    lwz     r2, KDP.ClearIntMask(r1)        ; Clear an interrupt via Cond Reg
    and     r0, r0, r2
    b       @return

########################################################################

    _align kExternalIntAlign
ExternalInt6
    mfsprg  r1, 0
    dcbz    0, r1
    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    lwz     r2, KDP.NKInfo.ExternalIntCount(r1)
    stw     r3, KDP.r3(r1)
    addi    r2, r2, 1
    stw     r2, KDP.NKInfo.ExternalIntCount(r1)

    mfmsr   r3
    stw     r4, KDP.r4(r1)
    stw     r5, KDP.r5(r1)
    stw     r6, KDP.r6(r1)
    stw     r7, KDP.r7(r1)
    stw     r8, KDP.r8(r1)

    mfsrr1  r5
    mfcr    r0

    lhz     r7, KDP.PageMap + PMDT.PageIdx(r1)
    lwz     r2, KDP.SysInfo.IntCntrBaseAddr(r1)
    cmpwi   r7, 0
    beq     @lowfirstpmdt
    and.    r6, r5, r2
    beq     @skipheaps
    li      r8, 0
    cmplwi  r7, 1
    ble     @stillnotgood

    subi    r7, r7, 1
    addi    r6, r1, KDP.PageMap + PMDT.PageCount
    add     r6, r6, r7
    lbz     r4, 0(r6)
    lwz     r7, KDP.SysInfo.IntPendingReg(r1)
    lis     r8, -0x8000
    srw     r8, r8, r4
    and.    r7, r7, r8
    beq     @loc_5A54
    lwz     r8, KDP.EmuIntLevelPtr(r1)
    lhz     r8, 0(r8)
    b       @stillnotgood

@loc_5A54
    subi    r6, r6, 1
    lbz     r6, 0(r6)
    ori     r8, r3, 0x10
    lis     r7, 6
    ori     r7, r7, 0xB0
    add     r7, r7, r2
    mfsrr0  r4
    mtmsr   r8
    isync
    li      r8, 0
    stw     r8, 0(r7)
    eieio
    lwz     r7, 0(r7)
    cmpwi   r6, 0
    beq     @loc_5AAC
    lis     r8, 5
    ori     r8, r8, 0
    add     r8, r8, r2
    rlwinm  r7, r6, 5,22,31
    add     r8, r8, r7
    lwz     r8, 0(r8)
    extrwi  r8, r8, 4,20
@loc_5AAC
    lis     r7, 6
    ori     r7, r7, 0x80
    add     r7, r7, r2
    stwbrx  r8, 0, r7
    eieio
    lwz     r7, 0(r7)
    mtmsr   r3
    isync
    mtsrr0  r4
    lhz     r7, KDP.PageMap + PMDT.PageIdx(r1)
    subi    r7, r7, 1
    sth     r7, KDP.PageMap + PMDT.PageIdx(r1)
    b       @stillnotgood

@skipheaps
    ori     r7, r3, 0x10
    lis     r6, 6
    ori     r6, r6, 0xA0
    add     r6, r6, r2
    lis     r8, 5
    ori     r8, r8, 0
    add     r8, r8, r2
    mfsrr0  r4
    mtmsr   r7
    isync
    lwz     r6, 0(r6)
    srwi    r6, r6, 24
    cmplwi  r6, 0x13
    bge     @loc_5BE4
    rlwinm  r7, r6, 5,22,31
    add     r8, r8, r7
    lis     r7, 6
    ori     r7, r7, 0x80
    add     r7, r7, r2
    lwz     r8, 0(r8)
    extrwi  r8, r8, 4,20
    stwbrx  r8, 0, r7
    eieio
    lwz     r7, 0(r7)
    xori    r7, r3, 0x8000
    mtmsr   r7
    isync
    mtsrr0  r4
    lhz     r7, KDP.PageMap + PMDT.PageIdx(r1)
    add     r4, r7, r1
    addi    r7, r7, 1
    stb     r6, KDP.PageMap + PMDT.PageCount(r4)
    sth     r7, KDP.PageMap + PMDT.PageIdx(r1)
    mtmsr   r3
    isync
    lwz     r7, KDP.SysInfo.IntPendingReg(r1)
    lis     r4, -0x8000
    srw     r4, r4, r6
    or      r7, r7, r4
    stw     r7, KDP.SysInfo.IntPendingReg(r1)
@stillnotgood

    mtsrr1  r5
    lwz     r7, KDP.r7(r1)
    lwz     r6, KDP.r6(r1)
    lwz     r5, KDP.r5(r1)
    lwz     r4, KDP.r4(r1)
    lwz     r3, KDP.EmuIntLevelPtr(r1)
    cmpwi   r8, 0
    beq     @loc_5BA4
    ori     r8, r8, 0x8000
@loc_5BA4
    sth     r8, 0(r3)
    mfsprg  r2, 2
    lwz     r8, KDP.r8(r1)
    lwz     r3, KDP.r3(r1)
    mtlr    r2
    beq     @loc_5BD8
    lwz     r2, KDP.PostIntMask(r1)
    or      r0, r0, r2
@loc_5BC4
    mtcr    r0
    lwz     r0, KDP.r0(r1)
    lwz     r2, KDP.r2(r1)
    mfsprg  r1, 1
    rfi

@loc_5BD8
    lwz     r2, KDP.ClearIntMask(r1)
    and     r0, r0, r2
    b       @loc_5BC4

@loc_5BE4
    li      r8, 0
    lis     r7, 6
    ori     r7, r7, 0xB0
    add     r7, r7, r2
    stw     r8, 0(r7)
    eieio
    lwz     r7, 0(r7)
    mtmsr   r3
    isync
    mtsrr0  r4
    b       @stillnotgood

@lowfirstpmdt
    addi    r7, r7, 1
    li      r8, 0
    sth     r7, KDP.PageMap + PMDT.PageIdx(r1)
    stw     r8, KDP.PageMap + PMDT.PageCount(r1)
    b       @stillnotgood
