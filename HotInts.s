; Frequently-used interrupt handlers

kHotIntAlign equ 6

########################################################################

    _align kHotIntAlign
DecrementerIntSys
; Increment the Sys/Alt CPU clocks, and the Dec-int counter
    mfsprg  r1, 0
    stmw    r2, KDP.r2(r1)
    mfdec   r31
    lwz     r30, KDP.OtherContextDEC(r1)

DecCommon ; DEC for Alternate=r30, System=r31
    mfxer   r29                         ; we will do carries

    lwz     r28, KDP.ProcInfo.DecClockRateHz(r1)
    stw     r28, KDP.OtherContextDEC(r1)
    mtdec   r28                         ; reset Sys and Alt decrementers

    subf    r31, r31, r28               ; System ticks actually elapsed
    subf    r30, r30, r28               ; Alternate ticks actually elapsed

    lwz     r28, KDP.NKInfo.SysContextCpuTime+4(r1)
    lwz     r27, KDP.NKInfo.SysContextCpuTime(r1)
    addc    r28, r28, r31
    addze   r27, r27
    stw     r28, KDP.NKInfo.SysContextCpuTime+4(r1)
    stw     r27, KDP.NKInfo.SysContextCpuTime(r1)

    lwz     r28, KDP.NKInfo.AltContextCpuTime+4(r1)
    lwz     r27, KDP.NKInfo.AltContextCpuTime(r1)
    addc    r28, r28, r30
    addze   r27, r27
    stw     r28, KDP.NKInfo.AltContextCpuTime+4(r1)
    stw     r27, KDP.NKInfo.AltContextCpuTime(r1)

    mtxer   r29

    stw     r0, KDP.r0(r1)
    mfsprg  r31, 1
    stw     r31, KDP.r1(r1)

    lwz     r31, KDP.NKInfo.DecrementerIntCount(r1)
    addi    r31, r31, 1
    stw     r31, KDP.NKInfo.DecrementerIntCount(r1)

    lmw     r27, KDP.r27(r1)
    mfsprg  r1, 2
    mtlr    r1
    mfsprg  r1, 1
    rfi

DecrementerIntAlt
    mfsprg  r1, 0
    stmw    r2, KDP.r2(r1)
    lwz     r31, KDP.OtherContextDEC(r1)
    mfdec   r30
    b       DecCommon

########################################################################

    _align kHotIntAlign
DataStorageInt ; to MemRetry! (see MROptab.s for register info)
    mfsprg  r1, 0
    stmw    r2, KDP.r2(r1)
    mfsprg  r11, 1
    stw     r0, KDP.r0(r1)
    stw     r11, KDP.r1(r1)

    mfsrr0  r10
    mfsrr1  r11
    mfsprg  r12, 2
    mfcr    r13

    mfmsr   r14
    _ori    r15, r14, MsrDR
    mtmsr   r15
    isync
    lwz     r27, 0(r10)                 ; r27 = instruction
    mtmsr   r14
    isync

EmulateViaMemRetry
    rlwinm. r18, r27, 18, 25, 29        ; r16 = 4 * rA (r0 wired to 0)
    lwz     r25, KDP.MRBase(r1)
    li      r21, 0
    beq     @r0
    lwzx    r18, r1, r18                ; r16 = contents of rA
@r0
    andis.  r26, r27, 0xec00            ; determine instruction form
    lwz     r16, KDP.Flags(r1)
    mfsprg  r24, 3
    rlwinm  r17, r27, 0, 6, 15          ; set MR status reg
    _mvbit  r16, bContextFlagTraceWhenDone, r16, bMsrSE
    bge     @xform

;dform
    rlwimi  r25, r27, 7, 26, 29
    rlwimi  r25, r27, 12, 25, 25
    lwz     r26, MROptabD-MRBase(r25)   ; last quarter of the X-form table, index = major opcode bits 51234
    extsh   r23, r27                    ; r23 = register offset field, sign-extended
    rlwimi  r25, r26, 26, 22, 29
    mtlr    r25                         ; dest = r25 = first of two function ptrs in table entry
    mtcr    r26                         ; using the flags in the arbitrary upper 16 bits of the table entry?
    add     r18, r18, r23               ; r18 = EA
    rlwimi  r17, r26, 6, 26, 5          ; set MR status reg
    blr

@xform
    rlwimi  r25, r27, 27, 26, 29
    rlwimi  r25, r27, 0, 25, 25
    rlwimi  r25, r27, 6, 23, 24
    lwz     r26, MROptabX-MRBase(r25)   ; index = extended opcode bits 8940123
    rlwinm  r23, r27, 23, 25, 29        ; need to calculate EA (this part gets rB)
    rlwimi  r25, r26, 26, 22, 29        ; prepare to jump to the primary routine
    mtlr    r25
    mtcr    r26
    lwzx    r23, r1, r23                ; get rB from saved registers
    rlwimi  r17, r26, 6, 26, 5          ; set MR status reg)
    add     r18, r18, r23               ; r18 = EA
    bclr    BO_IF_NOT, mrXformIgnoreIdxReg
    neg     r23, r23
    add     r18, r18, r23
    blr

########################################################################

    _align kHotIntAlign
AlignmentInt ; to MemRetry! (see MROptab.s for register info)
    mfsprg  r1, 0
    stmw    r2, KDP.r2(r1)

    lwz     r11, KDP.NKInfo.MisalignmentCount(r1)
    addi    r11, r11, 1
    stw     r11, KDP.NKInfo.MisalignmentCount(r1)

    mfsprg  r11, 1
    stw     r0, KDP.r0(r1)
    stw     r11, KDP.r1(r1)

    mfsrr0  r10
    mfsrr1  r11
    mfsprg  r12, 2
    mfcr    r13
    mfsprg  r24, 3
    mfdsisr r27
    mfdar   r18

    extrwi. r21, r27, 2, 15             ; determine instruction form using DSISR
    lwz     r25, KDP.MRBase(r1)
    rlwinm  r17, r27, 16, 0x03FF0000    ; insert rS/rD field from DSISR into MR status reg
    lwz     r16, KDP.Flags(r1)
    rlwimi  r25, r27, 24, 23, 29        ; look up DSISR opcode field in MROptab
    _mvbit  r16, bContextFlagTraceWhenDone, r16, bMsrSE
    bne     @xform

;dform
    lwz     r26, MROptabD-MRBase(r25)   ; last quarter of the X-form table, index = major opcode bits 51234
    mfmsr   r14
    rlwimi  r25, r26, 26, 22, 29        ; prepare to jump to the primary routine
    mtlr    r25
    _ori    r15, r14, MsrDR
    mtcr    r26
    rlwimi  r17, r26, 6, 26, 5          ; set the rest of the MR status register
    blr

@xform
    lwz     r26, MROptabX-MRBase(r25)   ; index = extended opcode bits 8940123
    mfmsr   r14
    rlwimi  r25, r26, 26, 22, 29        ; prepare to jump to the primary routine
    mtlr    r25
    _ori    r15, r14, MsrDR
    mtcr    r26
    rlwimi  r17, r26, 6, 26, 5
    bclr    BO_IF_NOT, mrSkipInstLoad
    mtmsr   r15
    isync
    lwz     r27, 0(r10)
    mtmsr   r14
    isync
    blr

########################################################################

SetMSRFlush
    sync
    mtmsr   r14
    isync
    mflr    r23
    icbi    0, r23
    isync
    blr
