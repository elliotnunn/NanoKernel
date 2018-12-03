; Entry point of kernel. Registers on entry:
rCI set r3 ; NKConfigurationInfo
rPI set r4 ; NKProcessorInfo
rSI set r5 ; NKSystemInfo
rDI set r6 ; NKDiagInfo
;       r7 ; 'RTAS' if present
;       r8 ; RTAS proc if present
rHI set r9 ; NKHWInfo

;   Other registers we use
rED set r8 ; Emulator Data Page

########################################################################

    li      r0, 0       ; Zero lots of fields

########################################################################

ClearSPRs
    mtsr    0, r0
    mtsr    1, r0
    mtsr    2, r0
    mtsr    3, r0
    mtsr    4, r0
    mtsr    5, r0
    mtsr    6, r0
    mtsr    7, r0
    mtsr    8, r0
    mtsr    9, r0
    mtsr    10, r0
    mtsr    11, r0
    mtsr    12, r0
    mtsr    13, r0
    mtsr    14, r0
    mtsr    15, r0

    mfpvr   r12
    srwi    r12, r12, 16
    cmpwi   r12, 1
    bne     @non601
;601
    mtspr   rtcl, r0
    mtspr   rtcu, r0
    mtspr   ibat0l, r0
    mtspr   ibat1l, r0
    mtspr   ibat2l, r0
    mtspr   ibat3l, r0
    b       @endif
@non601
    mtspr   tbl, r0
    mtspr   tbu, r0
    mtspr   ibat0u, r0
    mtspr   ibat1u, r0
    mtspr   ibat2u, r0
    mtspr   ibat3u, r0
    mtspr   dbat0u, r0
    mtspr   dbat1u, r0
    mtspr   dbat2u, r0
    mtspr   dbat3u, r0
@endif

########################################################################

TrimFirstBank
; Waste physical pages so that logi 0 = phys PA_RelocatedLowMemInit
    lwz     r12, NKConfigurationInfo.PA_RelocatedLowMemInit(rCI)

    addi    r10, rSI, NKSystemInfo.Bank0Start-4 ; new in G3:
@loop                                           ; ignore empty banks
    lwzu    r11, 8(r10) ; bank size
    cmpwi   r11, 0
    beq     @loop

    subf    r11, r12, r11       ; only if bank 0 is not already too high
    srawi   r11, r11, 31
    andc    r12, r12, r11
    lwz     r11, 0(r10) ; bank size
    subf    r11, r12, r11
    stw     r11, 0(r10)

    lwz     r11, -4(r10) ; bank start
    add     r11, r11, r12
    stw     r11, -4(r10)

    lwz     r11, NKSystemInfo.PhysicalMemorySize(rSI)
    subf    r11, r12, r11
    stw     r11, NKSystemInfo.PhysicalMemorySize(rSI)

########################################################################

InitKernelMemory
; Steal some physical RAM for kernel structures: kernel data page, HTAB, 68k page descriptors
    lwz     r15, NKSystemInfo.PhysicalMemorySize(rSI)   ; Size the HTAB for 2 entries per page, obeying
    subi    r15, r15, 1                                 ; the architecture's min and max size
    cntlzw  r12, r15
    lis     r14, 0x00ff
    srw     r14, r14, r12
    ori     r14, r14, 0xffff
    clrlwi  r14, r14, 9

    addis   r15, r15, 0x40                              ; Size the 68k Page Descriptor list
    rlwinm  r15, r15, 32-10, 10, 19                     ; (4b entry per page, padded to whole page)

    add     r15, r15, r14                               ; Total needed = 68k-PDs + KDP/EDP (2 pages) + HTAB
    addi    r15, r15, 0x2001

    addi    r10, rSI, NKSystemInfo.EndOfBanks           ; Choose bank that can fit everything (r15) while leaving
@nextbank                                               ; HTAB aligned to multiple of its own size (mask in r14).
    lwz     r11, -4(r10)
    lwzu    r12, -8(r10)
    add     r11, r12, r11
    andc    r13, r11, r14
    subf    r13, r15, r13
    cmplw   r13, r12
    blt     @nextbank
    cmplw   r13, r11
    bgt     @nextbank

    add     r12, r13, r15                               ; SDR1 = HTABORG || HTABMASK (16b each)
    subf    r12, r14, r12                               ; Leave HTAB pointer in r12
    inslwi  r12, r14, 16, 16
    mtspr   sdr1, r12

    clrrwi  r11, r12, 16                                ; Place the Kernel Data Page at HTAB - 0x2000
    subi    r1, r11, 0x2000
    lwz     r11, KDP.CrashSDR1(r1)
    mtsprg  0, r1
    cmpw    r12, r11
    lis     r11, 0x7fff
    bne     @nopanic
    subf    r11, r13, r1
    addi    r11, r11, KDP.CrashTop
@nopanic

    subf    r12, r14, r15                               ; Wipe the kernel page except kernel crash data
    subi    r12, r12, 1
@zeroloop
    subic.  r12, r12, 4
    subf    r10, r11, r12
    cmplwi  cr7, r10, KDP.CrashBtm - KDP.CrashTop
    ble     cr7, @skip
    stwx    r0, r13, r12
@skip
    bne     @zeroloop

########################################################################

InitInfoRecords
; Get copies of the PowerPC Info Records from HardwareInit
    lisori  r12, 'RTAS'
    cmpw    r7, r12
    bne     @nortas
    stw     r8, KDP.RTASDispatch(r1)
    lwz     r7, NKHWInfo.RTAS_PrivDataArea(rHI)
    stw     r7, KDP.RTASData(r1)
    addi    r11, r1, KDP.HWInfo
    li      r10, NKHWInfo.Size
@loop
    subic.  r10, r10, 4
    lwzx    r12, rHI, r10
    stwx    r12, r11, r10
    bgt     @loop
    b       @done
@nortas
    stw     r0, KDP.RTASDispatch(r1)
    stw     r0, KDP.RTASData(r1)
@done

    addi    r11, r1, KDP.ProcInfo
    li      r10, NKProcessorInfo.Size
@copyprocinfo
    subic.  r10, r10, 4
    lwzx    r12, rPI, r10
    stwx    r12, r11, r10
    bgt     @copyprocinfo

    addi    r11, r1, KDP.SysInfo
    li      r10, NKSystemInfo.Size
@copysysinfo
    subic.  r10, r10, 4
    lwzx    r12, rSI, r10
    stwx    r12, r11, r10
    bgt     @copysysinfo

    addi    r11, r1, KDP.DiagInfo
    li      r10, NKDiagInfo.Size
@copydiaginfo
    subic.  r10, r10, 4
    lwzx    r12, rDI, r10
    stwx    r12, r11, r10
    bgt     @copydiaginfo

########################################################################

InitKernelData
    bl      GetExtIntHandler ; moved here to free up r7 for return val

    stw     rCI, KDP.ConfigInfoPtr(r1)

    stw     r7, KDP.IntHandlerPtr(r1)

    addi    r12, r14, 1
    stw     r12, KDP.SysInfo.HashTableSize(r1)

    addi    rED, r1, 0x1000
    stw     rED, KDP.EDPPtr(r1)

    stw     r13, KDP.KernelMemoryBase(r1)
    add     r12, r13, r15
    stw     r12, KDP.KernelMemoryEnd(r1)

    lwz     r12, NKConfigurationInfo.PA_RelocatedLowMemInit(rCI)
    stw     r12, KDP.LowMemPtr(r1)

    lwz     r12, NKConfigurationInfo.SharedMemoryAddr(rCI)
    stw     r12, KDP.SharedMemoryAddr(r1)

    lwz     r12, NKConfigurationInfo.LA_EmulatorCode(rCI)
    lwz     r11, NKConfigurationInfo.KernelTrapTableOffset(rCI)
    add     r12, r12, r11
    stw     r12, KDP.EmuTrapTableLogical(r1)

    bl      * + 4
    mflr    r12
    addi    r12, r12, 4 - *
    stw     r12, KDP.CodeBase(r1)

    _kaddr  r12, r12, MRBase
    stw     r12, KDP.MRBase(r1)

    lwz     r12, NKConfigurationInfo.LA_EmulatorData(rCI)
    lwz     r11, NKConfigurationInfo.ECBOffset(rCI)
    add     r12, r12, r11
    stw     r12, KDP.SysContextPtrLogical(r1)

    add     r12, rED, r11
    stw     r12, KDP.SysContextPtr(r1)
    stw     r12, KDP.ContextPtr(r1)

    lwz     r12, NKConfigurationInfo.TestIntMaskInit(rCI)
    stw     r12, KDP.TestIntMask(r1)
    lwz     r12, NKConfigurationInfo.ClearIntMaskInit(rCI)
    stw     r12, KDP.ClearIntMask(r1)
    lwz     r12, NKConfigurationInfo.PostIntMaskInit(rCI)
    stw     r12, KDP.PostIntMask(r1)

    lwz     r12, NKConfigurationInfo.IplValueOffset(rCI)
    add     r12, rED, r12
    stw     r12, KDP.EmuIntLevelPtr(r1)

    lwz     r12, NKConfigurationInfo.SharedMemoryAddr(rCI)
    addi    r12, r12, 0x7c
    stw     r12, KDP.DebugIntPtr(r1)

    lwz     r12, NKConfigurationInfo.PageAttributeInit(rCI)
    stw     r12, KDP.PageAttributeInit(r1)

    addi    r13, r1, KDP.PageMap
    lwz     r12, NKConfigurationInfo.PageMapInitSize(rCI)
    stw     r13, KDP.PageMapPtr(r1)
    add     r13, r13, r12
    stw     r13, KDP.PageMapFreePtr(r1)

    stw     r0, 0x910(r1)   ; Zero first word of old PageMap in
                            ; case old code attempts access

########################################################################

InitInfoRecordPointers
; Userspace uses the pointers to find the PowerPC Info Records
    lwz     r11, NKConfigurationInfo.LA_InfoRecord(rCI)

    addi    r12, r11, 0xFC0
    stw     r12, 0xFC0(r1)
    stw     r0, 0xFC4(r1)

    addi    r12, r11, 0xFC8
    stw     r12, 0xFC8(r1)
    stw     r0, 0xFCC(r1)

    addi    r12, r11, KDP.HWInfo
    stw     r12, NKHWInfoPtr & 0xFFF(r1)
    li      r12, kHWInfoVer
    sth     r12, NKHWInfoVer & 0xFFF(r1)
    li      r12, NKHWInfo.Size
    sth     r12, NKHWInfoLen & 0xFFF(r1)

    addi    r12, r11, KDP.ProcInfo
    stw     r12, NKProcessorInfoPtr & 0xFFF(r1)
    li      r12, kProcessorInfoVer
    sth     r12, NKProcessorInfoVer & 0xFFF(r1)
    li      r12, NKProcessorInfo.Size
    sth     r12, NKProcessorInfoLen & 0xFFF(r1)

    addi    r12, r11, KDP.NKInfo
    stw     r12, NKNanoKernelInfoPtr & 0xFFF(r1)
    li      r12, kVersion
    sth     r12, NKNanoKernelInfoVer & 0xFFF(r1)
    li      r12, NKNanoKernelInfo.Size
    sth     r12, NKNanoKernelInfoLen & 0xFFF(r1)

    addi    r12, r11, KDP.DiagInfo
    stw     r12, NKDiagInfoPtr & 0xFFF(r1)
    li      r12, kDiagInfoVer
    sth     r12, NKDiagInfoVer & 0xFFF(r1)
    li      r12, NKDiagInfo.Size
    sth     r12, NKDiagInfoLen & 0xFFF(r1)

    addi    r12, r11, KDP.SysInfo
    stw     r12, NKSystemInfoPtr & 0xFFF(r1)
    li      r12, kSystemInfoVer
    sth     r12, NKSystemInfoVer & 0xFFF(r1)
    li      r12, NKSystemInfo.Size
    sth     r12, NKSystemInfoLen & 0xFFF(r1)

    addi    r12, r11, KDP.ProcInfo      ; redundant -- purpose unclear
    stw     r12, 0xFF8(r1)
    li      r12, kProcessorInfoVer
    sth     r12, 0xFFC(r1)
    li      r12, NKProcessorInfo.Size
    sth     r12, 0xFFE(r1)

########################################################################

InitEmulator
; Copy 16b boot version string ("Boot PDM 601 1.0")
    lwz     r11, NKConfigurationInfo.BootVersionOffset(rCI)
    lwz     r12, NKConfigurationInfo.BootstrapVersion(rCI)
    stwux   r12, r11, rED
    lwz     r12, NKConfigurationInfo.BootstrapVersion + 4(rCI)
    stw     r12, 4(r11)
    lwz     r12, NKConfigurationInfo.BootstrapVersion + 8(rCI)
    stw     r12, 8(r11)
    lwz     r12, NKConfigurationInfo.BootstrapVersion + 12(rCI)
    stw     r12, 12(r11)

; Init the ECB (Emulator ContextBlock) as if about to return from an exception handler
    lwz     r12, NKConfigurationInfo.LA_EmulatorCode(rCI)
    lwz     r11, NKConfigurationInfo.EmulatorEntryOffset(rCI)
    add     r12, r11, r12
    lwz     r11, NKConfigurationInfo.ECBOffset(rCI)
    add     r11, r11, rED
    stw     r12, CB.FaultSrcPC+4(r11)                       ; Return to Emulator's declared entry point

    lwz     r12, NKConfigurationInfo.LA_EmulatorData(rCI)   ; r3 = Emulator Data Page
    stw     r12, CB.FaultSrcR3+4(r11)

    lwz     r12, NKConfigurationInfo.LA_DispatchTable(rCI)  ; r4 = 512kb dispatch table
    stw     r12, CB.FaultSrcR4+4(r11)

    lwz     r12, KDP.EmuTrapTableLogical(r1)                ; address of ReturnFromException trap (why?)
    stw     r12, CB.IntraState.HandlerReturn+4(r11)

; Zero the first 8k of MacOS Low Memory
    lwz     r10, KDP.LowMemPtr(r1)
    li      r9, 0x2000
@zeroloop
    subic.  r9, r9, 4
    stwx    r0, r10, r9
    bne     @zeroloop

; Populate Low Memory with the address/value pairs in ConfigInfo
    lwz     r11, NKConfigurationInfo.MacLowMemInitOffset(rCI)
    lwz     r10, KDP.LowMemPtr(r1)
    lwzux   r9, r11, rCI
@setloop
    mr.     r9, r9
    beq     @donelm
    lwzu    r12, 4(r11)
    stwx    r12, r10, r9
    lwzu    r9, 4(r11)
    b       @setloop
@donelm

########################################################################

    include 'ProcessorInfo.s'

########################################################################

; Calculate NanoKernel "flags" -- empirically, by attemping to wang MQ
    lwz     r8, KDP.CodeBase(r1)
    _kaddr  r8, r8, IgnoreSoftInt
    stw     r8, KDP.VecTblSystem.Program(r1)
    addi    r8, r1, KDP.VecTblSystem
    mtsprg  3, r8

    lis     r8, GlobalFlagMQReg >> 16
    mtspr   mq, r8
    li      r8, 0
    mfspr   r8, mq
    _ori    r7, r8, GlobalFlagSystem
    stw     r7, KDP.Flags(r1)

; Start user-mode execution at ReturnFromException trap
    lwz     r10, KDP.EmuTrapTableLogical(r1)

; Calculate MSR (Machine Status Register) for userspace
    mfmsr   r14
    andi.   r14, r14, MsrIP
    ori     r15, r14, MsrME | MsrDR | MsrRI                         ; does r15 even get used?
    ori     r11, r14, MsrEE | MsrPR | MsrME | MsrIR | MsrDR | MsrRI ; <- this is the real one

; Zero out registers
    li      r13, 0          ; Condition Register
    li      r12, 0          ; Link Register
    li      r0, 0
    li      r2, 0
    li      r3, 0           ; make KCallReturnFromException return gracefully
    li      r4, 0

########################################################################

InitDecrementer
; Required for the System and Alternate context clocks to run
    lwz     r8, KDP.ProcInfo.DecClockRateHz(r1)
    stw     r8, KDP.OtherContextDEC(r1)
    mtdec   r8

########################################################################

    b       Reset
