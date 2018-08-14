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

    _align kExternalIntAlign
ExternalInt0
    mfsprg  r1, 0                           ; Init regs and increment ctr
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
    stw     r3, 0(r3)
    mtmsr   r2
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
    li      r0, 0xC0            ; clear AMIC CPU interrupt by setting bits 6-7
    stb     r0, -0x6000(r2)
    eieio
    lbz     r0, -0x6000(r2)     ; read AMIC Irq flags
    mtmsr   r3                  ; disable data address translation
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
; This is the handler for external interrupts on the TNT board equipped
; with the GrandCentral I/O Controller ASIC.
; Because GrandCentral is a little-endian device, we'll use the
; byte-reverse load and store instructions to access its registers.

    _align kExternalIntAlign
ExtIntHandlerTNT
    mfsprg  r1, 0                           ; Init regs and increment ctr
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
    mfsrr0  r4
    mfsrr1  r5
    mtmsr   r3                  ; enable data address translation
    lis     r3, 0x8000
    stw     r3, 0x28(r2)        ; write ifMode1Clear flag to interrupt clear register
    eieio
    lwz     r3, 0x2C(r2)        ; read interrupt levels register
    mtmsr   r0                  ; disable data address translation
    mtsrr0  r4
    mtsrr1  r5
    lwz     r4, KDP.r4(r1)
    lwz     r5, KDP.r5(r1)

    mfcr    r0                  ; reset CR

    rlwinm. r2, r3, 0, 11, 11   ; set IPL to 7
    li      r2, 7               ; if ExtNMI IRQ is asserted
    bne     @gotnum             ;

    rlwinm  r2, r3, 0, 15, 16   ; SCC A and SCC B
    rlwimi. r2, r3, 0, 21, 31   ; together with all DMA IRQs
    li      r2, 4               ; will get the priority level 4
    bne     @gotnum

    rlwinm. r2, r3, 0, 18, 18   ; Ethernet MACE is the only device allowed to
    li      r2, 3               ; interrupt at level 3
    bne     @gotnum

    andis.  r2, r3, 0x7FEA      ; all other devices including SCSI, PCI, Audio,
    rlwimi. r2, r3, 0, 19, 20   ; Floppy etc. except VIA1
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
