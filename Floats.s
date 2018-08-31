    _align 6
FPUnavailInt
; Reload the FPU
    mfsprg  r1, 0
    stw     r11, KDP.FloatTemp1(r1)
    lwz     r11, KDP.NKInfo.FPUReloadCount(r1)
    stw     r6, KDP.FloatTemp2(r1)
    addi    r11, r11, 1
    stw     r11, KDP.NKInfo.FPUReloadCount(r1)

    mfsrr1  r11
    _ori    r11, r11, MsrFP
    mtsrr1  r11

    mfmsr   r11             ; need this to access float registers
    _ori    r11, r11, MsrFP
    lwz     r6, KDP.ContextPtr(r1)
    mtmsr   r11
    isync

    bl      LoadFloats

    lwz     r11, KDP.FloatTemp1(r1)
    lwz     r6, KDP.FloatTemp2(r1)

    mfsprg  r1, 2
    mtlr    r1
    mfsprg  r1, 1

    rfi

########################################################################

ThawFPU
    rlwinm. r8, r11, 0, MsrFP
    bnelr
QuickThawFPU
    lwz     r8, CB.FPSCR+4(r6)
    rlwinm. r8, r8, 1, 0, 0

    mfmsr   r8
    _ori    r8, r8, MsrFP
    beqlr
    mtmsr   r8
    isync

    _ori    r11, r11, MsrFP

LoadFloats
    lfd     f31, CB.FPSCR(r6)
    lfd     f0, CB.f0(r6)
    lfd     f1, CB.f1(r6)
    lfd     f2, CB.f2(r6)
    lfd     f3, CB.f3(r6)
    lfd     f4, CB.f4(r6)
    lfd     f5, CB.f5(r6)
    lfd     f6, CB.f6(r6)
    lfd     f7, CB.f7(r6)
    mtfs    f31
    lfd     f8, CB.f8(r6)
    lfd     f9, CB.f9(r6)
    lfd     f10, CB.f10(r6)
    lfd     f11, CB.f11(r6)
    lfd     f12, CB.f12(r6)
    lfd     f13, CB.f13(r6)
    lfd     f14, CB.f14(r6)
    lfd     f15, CB.f15(r6)
    lfd     f16, CB.f16(r6)
    lfd     f17, CB.f17(r6)
    lfd     f18, CB.f18(r6)
    lfd     f19, CB.f19(r6)
    lfd     f20, CB.f20(r6)
    lfd     f21, CB.f21(r6)
    lfd     f22, CB.f22(r6)
    lfd     f23, CB.f23(r6)
    lfd     f24, CB.f24(r6)
    lfd     f25, CB.f25(r6)
    lfd     f26, CB.f26(r6)
    lfd     f27, CB.f27(r6)
    lfd     f28, CB.f28(r6)
    lfd     f29, CB.f29(r6)
    lfd     f30, CB.f30(r6)
    lfd     f31, CB.f31(r6)

    blr

########################################################################

FreezeFPU
    mfmsr   r8
    _ori    r8, r8, MsrFP
    mtmsr   r8
    isync

    rlwinm  r11, r11, 0, ~MsrFP

    stfd    f0, CB.f0(r6)
    stfd    f1, CB.f1(r6)
    stfd    f2, CB.f2(r6)
    stfd    f3, CB.f3(r6)
    stfd    f4, CB.f4(r6)
    stfd    f5, CB.f5(r6)
    stfd    f6, CB.f6(r6)
    stfd    f7, CB.f7(r6)
    stfd    f8, CB.f8(r6)
    stfd    f9, CB.f9(r6)
    stfd    f10, CB.f10(r6)
    stfd    f11, CB.f11(r6)
    stfd    f12, CB.f12(r6)
    stfd    f13, CB.f13(r6)
    stfd    f14, CB.f14(r6)
    stfd    f15, CB.f15(r6)
    stfd    f16, CB.f16(r6)
    stfd    f17, CB.f17(r6)
    stfd    f18, CB.f18(r6)
    stfd    f19, CB.f19(r6)
    stfd    f20, CB.f20(r6)
    stfd    f21, CB.f21(r6)
    stfd    f22, CB.f22(r6)
    stfd    f23, CB.f23(r6)
    mffs    f0
    stfd    f24, CB.f24(r6)
    stfd    f25, CB.f25(r6)
    stfd    f26, CB.f26(r6)
    stfd    f27, CB.f27(r6)
    stfd    f28, CB.f28(r6)
    stfd    f29, CB.f29(r6)
    stfd    f30, CB.f30(r6)
    stfd    f31, CB.f31(r6)
    stfd    f0, CB.FPSCR(r6)

    blr

########################################################################

; Interface between MemRetry integer and float code

    MACRO
    MakeFloatJumpTable &OPCODE, &DEST, &highest==31
    if &highest > 0
        MakeFloatJumpTable &OPCODE, &DEST, highest = (&highest) - 1
    endif
    &OPCODE &highest, KDP.FloatScratch(r1)
    b       &DEST
    ENDM

LFDTable
    MakeFloatJumpTable  lfd, MRSecDone
STFDTable
    MakeFloatJumpTable  stfd, MRDoneTableSTFD
