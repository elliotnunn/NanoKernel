Emulate
    mfmsr   r9
    _ori    r8, r9, MsrDR
    mtmsr   r8
    lwz     r8, 0(r10)
    mtmsr   r9

    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    stw     r3, KDP.r3(r1)
    stw     r4, KDP.r4(r1)
    stw     r5, KDP.r5(r1)
    lwz     r9, CB.r7+4(r6)
    stw     r9, KDP.r7(r1)
    lwz     r9, CB.r8+4(r6)
    stw     r9, KDP.r8(r1)
    lwz     r9, CB.r9+4(r6)
    stw     r9, KDP.r9(r1)
    lwz     r9, CB.r10+4(r6)
    stw     r9, KDP.r10(r1)
    lwz     r9, CB.r11+4(r6)
    stw     r9, KDP.r11(r1)
    lwz     r9, CB.r12+4(r6)
    stw     r9, KDP.r12(r1)
    lwz     r9, CB.r13+4(r6)
    stw     r9, KDP.r13(r1)
    stmw    r14, KDP.r14(r1)

    rlwinm  r9, r8, 6, 15, 31
    cmplwi  r9, 0xB99F
    beq     @MFTB

    rlwinm  r9, r8, 17, 15, 20
    insrwi  r9, r8, 11, 21
    cmplwi  r9, 0xFFAE
    beq     @STFIWX

@FAIL
    li      r8, ecInvalidInstr
    b       Exception

@MFTB
    extrwi  r9, r8, 10, 11          ; r9 = tbr field
    cmplwi  cr7, r9, 0x188          ; TBL=268, mangled
    cmplwi  cr6, r9, 0x1A8          ; TBU=269, mangled
    cror    15, cr6_eq, cr7_eq
    bc      BO_IF_NOT, 15, @FAIL

@retry_rtc
    mfspr   r20, rtcu
    mfspr   r21, rtcl
    mfspr   r23, rtcu
    xor.    r23, r23, r20
    lis     r23, 1000000000 >> 16
    rlwinm  r28, r8, 13, 25, 29     ; r28 = dest register number * 4
    ori     r23, r23, 1000000000 & 0xFFFF
    bne     @retry_rtc

    mullw   r8, r20, r23
    mulhwu  r20, r20, r23
    mfxer   r23
    addc    r21, r21, r8
    addze   r20, r20
    mtxer   r23
    lwz     r23, KDP.NKInfo.EmulatedUnimpInstCount(r1)
    rlwimi  r7, r7, 27, 26, 26      ; ContextFlagTraceWhenDone = MsrSE
    addi    r23, r23, 1
    stw     r23, KDP.NKInfo.EmulatedUnimpInstCount(r1)

    stwx    r21, r1, r28            ; save register into EWA
    mr      r16, r7
    beq     cr7, MRSecDone          ; TBL
    stwx    r20, r1, r28
    b       MRSecDone               ; TBU

@STFIWX
    lwz     r23, KDP.NKInfo.EmulatedUnimpInstCount(r1)
    mr      r27, r8
    addi    r23, r23, 1
    stw     r23, KDP.NKInfo.EmulatedUnimpInstCount(r1)
    mfmsr   r14
    _ori    r15, r14, MsrDR
    b       EmulateViaMemRetry
