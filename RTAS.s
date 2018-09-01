; Run-Time Abstraction Services

KCallRTASDispatch
    lwz     r8, KDP.RTASDispatch(r1)
    cmpwi   r8, 0
    bne     @rtaspresent
    li      r3, -1
    b       ReturnFromInt
@rtaspresent

    mtcrf   crMaskFlags, r7
    lwz     r9, KDP.SysContextPtr(r1)

;<STOLEN FROM=SwitchContext>
    lwz     r8, KDP.Enables(r1)
    stw     r7, CB.InterState.Flags(r6)
    stw     r8, CB.InterState.Enables(r6)

    bc      BO_IF_NOT, bContextFlagMemRetryErr, @can_dispose_mr_state
    stw     r17, CB.InterState.MemRetStatus+4(r6)
    stw     r20, CB.InterState.MemRetData(r6)
    stw     r21, CB.InterState.MemRetData+4(r6)
    stw     r19, CB.InterState.MemRetEAR+4(r6)
    stw     r18, CB.InterState.MemRetEA+4(r6)
    lmw     r14, KDP.r14(r1)
@can_dispose_mr_state

    mfxer   r8
    stw     r13, CB.CR+4(r6)
    stw     r8, CB.XER+4(r6)
    stw     r12, CB.LR+4(r6)
    mfctr   r8
    stw     r10, CB.PC+4(r6)
    stw     r8, CB.CTR+4(r6)

    bc      BO_IF_NOT, bGlobalFlagMQReg, @no_mq
    lwz     r8, CB.MQ+4(r9)
    mfspr   r12, mq
    mtspr   mq, r8
    stw     r12, CB.MQ+4(r6)
@no_mq

    lwz     r8, KDP.r1(r1)
    stw     r0, CB.r0+4(r6)
    stw     r8, CB.r1+4(r6)
    stw     r2, CB.r2+4(r6)
    stw     r3, CB.r3+4(r6)
    stw     r4, CB.r4+4(r6)
    lwz     r8, KDP.r6(r1)
    stw     r5, CB.r5+4(r6)
    stw     r8, CB.r6+4(r6)
    andi.   r8, r11, MsrFP
    stw     r14, CB.r14+4(r6)
    stw     r15, CB.r15+4(r6)
    stw     r16, CB.r16+4(r6)
    stw     r17, CB.r17+4(r6)
    stw     r18, CB.r18+4(r6)
    stw     r19, CB.r19+4(r6)
    stw     r20, CB.r20+4(r6)
    stw     r21, CB.r21+4(r6)
    stw     r22, CB.r22+4(r6)
    stw     r23, CB.r23+4(r6)
    stw     r24, CB.r24+4(r6)
    stw     r25, CB.r25+4(r6)
    stw     r26, CB.r26+4(r6)
    stw     r27, CB.r27+4(r6)
    stw     r28, CB.r28+4(r6)
    stw     r29, CB.r29+4(r6)
    stw     r30, CB.r30+4(r6)
    stw     r31, CB.r31+4(r6)
    bnel    FreezeFPU
;</STOLEN>

    stw     r11, CB.MSR+4(r6)
    mr      r27, r3
    addi    r29, r1, KDP.CurDBAT0
    bl      GetPhysical ; EA r27, batPtr r29 // PA r31, EQ=Fail
    beql    CrashRTAS
    rlwimi  r3, r31, 0, 0xFFFFF000
    lhz     r8, 4(r3)
    cmpwi   r8, 0
    beq     @something

    slwi    r8, r8, 2
    lwzx    r27, r8, r3
    addi    r29, r1, KDP.CurDBAT0
    bl      GetPhysical
    beql    CrashRTAS
    lwzx    r9, r8, r3
    rlwimi  r9, r31, 0, 0xFFFFF000
    stwx    r9, r8, r3
    li      r9, 0
    sth     r9, 4(r3)

@something
    lwz     r4, KDP.RTASData(r1)
    mfmsr   r8
    andi.   r8, r8, ~(0xFFFF0000|MsrEE|MsrPR|MsrFP|MsrFE0|MsrSE|MsrBE|MsrFE1|MsrIR|MsrDR)
    mtmsr   r8
    isync

    lwz     r9, KDP.RTASDispatch(r1)
    bl      @DO_IT

    mfsprg  r1, 0
    lwz     r6, KDP.ContextPtr(r1)
    lwz     r8, CB.InterState.Flags(r6)
    lwz     r11, CB.MSR+4(r6)
    mr      r7, r8

;<STOLEN FROM=SwitchContext>
    andi.   r8, r11, MsrFE0 + MsrFE1                ; FP exceptions enabled in new context?

    lwz     r8, CB.InterState.Enables(r6)
    lwz     r13, CB.CR+4(r6)
    stw     r8, KDP.Enables(r1)
    lwz     r8, CB.XER+4(r6)
    lwz     r12, CB.LR+4(r6)
    mtxer   r8
    lwz     r8, CB.CTR+4(r6)
    lwz     r10, CB.PC+4(r6)
    mtctr   r8

    bnel    QuickThawFPU                            ; FP exceptions enabled, so load FPU

;   stwcx.  r0, 0, r1                               ; present in orig code in SwitchContext

    lwz     r8, CB.r1+4(r6)
    lwz     r0, CB.r0+4(r6)
    stw     r8, KDP.r1(r1)
    lwz     r2, CB.r2+4(r6)
    lwz     r3, CB.r3+4(r6)
    lwz     r4, CB.r4+4(r6)
    lwz     r8, CB.r6+4(r6)
    lwz     r5, CB.r5+4(r6)
    stw     r8, KDP.r6(r1)
    lwz     r14, CB.r14+4(r6)
    lwz     r15, CB.r15+4(r6)
    lwz     r16, CB.r16+4(r6)
    lwz     r17, CB.r17+4(r6)
    lwz     r18, CB.r18+4(r6)
    lwz     r19, CB.r19+4(r6)
    lwz     r20, CB.r20+4(r6)
    lwz     r21, CB.r21+4(r6)
    lwz     r22, CB.r22+4(r6)
    lwz     r23, CB.r23+4(r6)
    lwz     r24, CB.r24+4(r6)
    lwz     r25, CB.r25+4(r6)
    lwz     r26, CB.r26+4(r6)
    lwz     r27, CB.r27+4(r6)
    lwz     r28, CB.r28+4(r6)
    lwz     r29, CB.r29+4(r6)
    lwz     r30, CB.r30+4(r6)
    lwz     r31, CB.r31+4(r6)
;</STOLEN>

    li      r3, 0
    b       ReturnFromInt

@DO_IT
    mtctr   r9
    bctr
