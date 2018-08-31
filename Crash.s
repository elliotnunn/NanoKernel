Crash
    mfsprg  r1, 0

    stw     r0, KDP.CrashR0(r1)

    mfsprg  r0, 1
    stw     r0, KDP.CrashR1(r1)

    stmw    r2, KDP.CrashR2(r1)

    mfcr    r0
    stw     r0, KDP.CrashCR(r1)

    mfpvr   r0
    andis.  r0, r0, 0xFFFE
    bne     @not601_mq
    mfspr   r0, mq
    stw     r0, KDP.CrashMQ(r1)
@not601_mq

    mfxer   r0
    stw     r0, KDP.CrashXER(r1)

    mfsprg  r0, 2
    stw     r0, KDP.CrashLR(r1)

    mfctr   r0
    stw     r0, KDP.CrashCTR(r1)

    mfspr   r0, pvr
    stw     r0, KDP.CrashPVR(r1)

    mfspr   r0, dsisr
    stw     r0, KDP.CrashDSISR(r1)
    mfspr   r0, dar
    stw     r0, KDP.CrashDAR(r1)

    mfpvr   r0
    andis.  r0, r0, 0xFFFE
    bne     @not601_rtc
    mfspr   r0, rtcu
    stw     r0, KDP.CrashRTCU(r1)
    mfspr   r0, rtcl
    stw     r0, KDP.CrashRTCL(r1)
@not601_rtc

    mfspr   r0, dec
    stw     r0, KDP.CrashDEC(r1)

    mfspr   r0, hid0
    stw     r0, KDP.CrashHID0(r1)

    mfspr   r0, sdr1
    stw     r0, KDP.CrashSDR1(r1)

    mfsrr0  r0
    stw     r0, KDP.CrashSRR0(r1)
    mfsrr1  r0
    stw     r0, KDP.CrashSRR1(r1)
    mfmsr   r0
    stw     r0, KDP.CrashMSR(r1)

    mfsr    r0, 0
    stw     r0, KDP.CrashSR0(r1)
    mfsr    r0, 1
    stw     r0, KDP.CrashSR1(r1)
    mfsr    r0, 2
    stw     r0, KDP.CrashSR2(r1)
    mfsr    r0, 3
    stw     r0, KDP.CrashSR3(r1)
    mfsr    r0, 4
    stw     r0, KDP.CrashSR4(r1)
    mfsr    r0, 5
    stw     r0, KDP.CrashSR5(r1)
    mfsr    r0, 6
    stw     r0, KDP.CrashSR6(r1)
    mfsr    r0, 7
    stw     r0, KDP.CrashSR7(r1)
    mfsr    r0, 8
    stw     r0, KDP.CrashSR8(r1)
    mfsr    r0, 9
    stw     r0, KDP.CrashSR9(r1)
    mfsr    r0, 10
    stw     r0, KDP.CrashSR10(r1)
    mfsr    r0, 11
    stw     r0, KDP.CrashSR11(r1)
    mfsr    r0, 12
    stw     r0, KDP.CrashSR12(r1)
    mfsr    r0, 13
    stw     r0, KDP.CrashSR13(r1)
    mfsr    r0, 14
    stw     r0, KDP.CrashSR14(r1)
    mfsr    r0, 15
    stw     r0, KDP.CrashSR15(r1)

    mfmsr   r0
    _ori    r0, r0, MsrFP
    mtmsr   r0
    isync
    stfd    f0, KDP.CrashF0(r1)
    stfd    f1, KDP.CrashF1(r1)
    stfd    f2, KDP.CrashF2(r1)
    stfd    f3, KDP.CrashF3(r1)
    stfd    f4, KDP.CrashF4(r1)
    stfd    f5, KDP.CrashF5(r1)
    stfd    f6, KDP.CrashF6(r1)
    stfd    f7, KDP.CrashF7(r1)
    stfd    f8, KDP.CrashF8(r1)
    stfd    f9, KDP.CrashF9(r1)
    stfd    f10, KDP.CrashF10(r1)
    stfd    f11, KDP.CrashF11(r1)
    stfd    f12, KDP.CrashF12(r1)
    stfd    f13, KDP.CrashF13(r1)
    stfd    f14, KDP.CrashF14(r1)
    stfd    f15, KDP.CrashF15(r1)
    stfd    f16, KDP.CrashF16(r1)
    stfd    f17, KDP.CrashF17(r1)
    stfd    f18, KDP.CrashF18(r1)
    stfd    f19, KDP.CrashF19(r1)
    stfd    f20, KDP.CrashF20(r1)
    stfd    f21, KDP.CrashF21(r1)
    stfd    f22, KDP.CrashF22(r1)
    stfd    f23, KDP.CrashF23(r1)
    stfd    f24, KDP.CrashF24(r1)
    stfd    f25, KDP.CrashF25(r1)
    stfd    f26, KDP.CrashF26(r1)
    stfd    f27, KDP.CrashF27(r1)
    stfd    f28, KDP.CrashF28(r1)
    stfd    f29, KDP.CrashF29(r1)
    stfd    f30, KDP.CrashF30(r1)
    stfd    f31, KDP.CrashF31(r1)
    mffs    f31
    lwz     r0, KDP.CrashF31+4(r1)
    stfd    f31, KDP.CrashF31+4(r1)
    stw     r0, KDP.CrashF31+4(r1)

    mflr    r0
    stw     r0, KDP.CrashCaller(r1)

; Now spin
    lis     r2, 2           ; Count down from 64k to find a zero
@nonzero
    lwzu    r0, -4(r2)
    mr.     r2, r2
    bne     @nonzero

    mfpvr   r0
    andis.  r0, r0, 0xFFFE
    bne     @not601_rtc2
@retryrtc                   ; Save RTC in "Mac/Smurf shared message mem"
    mfspr   r2, rtcu
    mfspr   r3, rtcl
    mfspr   r0, rtcu
    xor.    r0, r0, r2
    bne     @retryrtc
@not601_rtc2
    lwz     r1, KDP.SharedMemoryAddr(r1)
    stw     r2, 0(r1)
    ori     r3, r3, 1
    stw     r3, 4(r1)

    dcbf    0, r1
    sync

@loopforever
    lwz     r1, 0(0)
    addi    r1, r1, 1
    stw     r1, 0(0)
    li      r1, 0
    dcbst   r1, r1
    b       @loopforever
