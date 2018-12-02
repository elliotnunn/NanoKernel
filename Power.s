KCallPowerDispatch
; Validate arguments. Why fail silently when r4 & CR != 0?
    cmplwi  cr7, r3, 7                      ; selector 0-3 + flush-cache bit 4
    and.    r8, r4, r13
    bgt     cr7, powRetNeg1
    bne     powRet0

    lwz     r9, KDP.CodeBase(r1)

    stmw    r27, KDP.r27(r1)

    lwz     r31, KDP.VecTblSystem.SystemReset(r1)
    lwz     r30, KDP.VecTblSystem.External(r1)
    lwz     r29, KDP.VecTblSystem.Decrementer(r1)

    _kaddr  r28, r9, powIgnoreDecrementerInt
    stw     r28, KDP.VecTblSystem.Decrementer(r1)

    _kaddr  r28, r9, WakeFromNap

    rlwinm  r26, r3, 0, 4                   ; Mask out flush-cache bit,
    clrlwi  r3, r3, 30                      ; removing it from selector

; Set Hardware Imp-Dependent Reg 0 (HID0) bit in order to "flavour" MSR[POW]
    lbz     r8, KDP.PowerHID0Select(r1)     ; Q: DOZE, NAP or SLEEP?
    slwi    r3, r3, 1                       ; A: r3 (=0/1) selects one of the 2-bit
    addi    r3, r3, 26                      ; fields in PowerHID0Select, which in
    rlwnm   r3, r8, r3, %11                 ; turn specifies a HID0 bit

    lbz     r9, KDP.PowerHID0Enable(r1)     ; Q: Should I wang the bit chosen above?
    cmpwi   r9, 0                           ; Should I set HID0[NHR]?
    beq     @no_hid0                        ; A: PowerHID0Enable
    mfspr   r27, hid0
    subi    r28, r28, 4                     ; If setting HID0, move WakeFromNap label below:
    mr      r8, r27
    cmpwi   r9, 1
    beq     @no_hid0_powerbit
    oris    r9, r3, 0x0100
    srw     r9, r9, r9
    rlwimi  r8, r9, 0, 8, 10
@no_hid0_powerbit
    oris    r8, r8, 1                       ; HID0[NHR] ("Not Hard Reset", can be set
    mtspr   hid0, r8                        ; by kernel to prove that reset is "warm")
@no_hid0

; These are our two routes out of heck
    stw     r28, KDP.VecTblSystem.SystemReset(r1)
    stw     r28, KDP.VecTblSystem.External(r1)

; Back up and silence the decrementer
    mfdec   r28
    lis     r8, 0x7fff
    mtdec   r8

    cmplwi  r26, 4
    beql    FlushCaches

; Set MSR bits.  causes HID0[DOZE/NAP/SLEEP] to take effect
    mfmsr   r8
    _ori    r8, r8, MsrEE | MsrRI
    mtmsr   r8

; Set MSR[POW] and wait for HID0 drugs to take effect
    cmplwi  r3, 0
    beq     @sleep
    _ori    r8, r8, MsrPOW
@sleep
    sync
    mtmsr   r8
    isync
    b       @sleep

; Wake! HID0 will be restored if it was set (see "subi" above)
    mtspr   hid0, r27
WakeFromNap
    mfsprg  r1, 2
    mtlr    r1
    mfsprg  r1, 1

; Restore decrementer
    mfdec   r9
    lis     r8, 0x7fff
    mtdec   r8
    mtdec   r28

; Restore this global vector table
    stw     r29, KDP.VecTblSystem.Decrementer(r1)
    stw     r30, KDP.VecTblSystem.External(r1)
    stw     r31, KDP.VecTblSystem.SystemReset(r1)

    lmw     r27, KDP.r27(r1)

powRet0
    li      r3, 0
    b       ReturnFromInt
powRetNeg1
    li      r3, -1
    b       ReturnFromInt

powIgnoreDecrementerInt
    lis     r1, 0x7fff
    mtdec   r1
    mfsprg  r1, 2
    mtlr    r1
    mfsprg  r1, 1
    rfi
