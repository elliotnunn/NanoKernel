KCallPowerDispatch
; Validate arguments. Why fail silently when r4 & CR != 0?
    cmplwi  cr7, r3, 11                     ; (selector 0-3 + flush-cache bit 4) OR selector 8+
    and.    r8, r4, r13
    bgt     cr7, powRetNeg1
    bne     powRet0

    cmplwi  cr7, r3, 11
    beq     cr7, PowInfiniteLoop
    cmplwi  cr7, r3, 8
    beq     cr7, PowSuspend
    cmplwi  cr7, r3, 9
    beq     cr7, PowSetICCR

    lwz     r9, KDP.CodeBase(r1)

    stw     r26, CB.r26+4(r6)
    stw     r27, CB.r27+4(r6)
    stw     r28, CB.r28+4(r6)
    stw     r29, CB.r29+4(r6)
    stw     r30, CB.r30+4(r6)
    stw     r31, CB.r31+4(r6)

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
    isync

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

    lwz     r26, CB.r26+4(r6)
    lwz     r27, CB.r27+4(r6)
    lwz     r28, CB.r28+4(r6)
    lwz     r29, CB.r29+4(r6)
    lwz     r30, CB.r30+4(r6)
    lwz     r31, CB.r31+4(r6)

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

########################################################################
; (New with G3) What the user interface calls "Sleep" mode
PowSuspend ; returns r3 = 0
    stw     r26, CB.r26+4(r6)
    stw     r27, CB.r27+4(r6)
    stw     r28, CB.r28+4(r6)
    stw     r29, CB.r29+4(r6)
    stw     r30, CB.r30+4(r6)
    stw     r31, CB.r31+4(r6)

; Disable caches without losing data
    bl      FlushCaches
    mfspr   r9, hid0                ; L1 cache via HID0 register
    rlwinm  r9, r9, 0, ~0x00004000  ; clear HID0[DCE=dcache-enable]
    rlwinm  r9, r9, 0, ~0x00008000  ; clear HID0[ICE=icache-enable]
    mtspr   hid0, r9
    sync
    isync
    lwz     r26, KDP.ProcInfo.ProcessorFlags(r1); L2 cache via L2CR
    andi.   r26, r26, 1 << NKProcessorInfo.hasL2CR
    beq     @nol2cr
    mfspr   r9, l2cr
    rlwinm  r9, r9, 0, ~0x80000000  ; clear L2CR[L2E=enable]
    mtspr   l2cr, r9
    sync
    isync
    stw     r9, KDP.ProcState.saveL2CR(r1)
@nol2cr

; Save heaps of state...
    stw     r0, CB.r0+4(r6)
    stw     r1, CB.r1+4(r6)
    stw     r2, CB.r2+4(r6)
    stw     r3, CB.r3+4(r6)
    stw     r4, CB.r4+4(r6)
    stw     r5, CB.r5+4(r6)
    stw     r6, CB.r6+4(r6)
    stw     r7, CB.r7+4(r6)
    stw     r8, CB.r8+4(r6)
    stw     r9, CB.r9+4(r6)
    stw     r10, CB.r10+4(r6)
    stw     r11, CB.r11+4(r6)
    stw     r12, CB.r12+4(r6)
    stw     r13, CB.r13+4(r6)
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

    mfcr    r9
    stw     r9, CB.CR+4(r6)

    andi.   r8, r11, MsrFP
    beq     @nofsave
    mffs    f9
    stw     r9, CB.FPSCR+4(r6)
    stw     r0, CB.f0+4(r6)
    stw     r1, CB.f1+4(r6)
    stw     r2, CB.f2+4(r6)
    stw     r3, CB.f3+4(r6)
    stw     r4, CB.f4+4(r6)
    stw     r5, CB.f5+4(r6)
    stw     r6, CB.f6+4(r6)
    stw     r7, CB.f7+4(r6)
    stw     r8, CB.f8+4(r6)
    stw     r9, CB.f9+4(r6)
    stw     r10, CB.f10+4(r6)
    stw     r11, CB.f11+4(r6)
    stw     r12, CB.f12+4(r6)
    stw     r13, CB.f13+4(r6)
    stw     r14, CB.f14+4(r6)
    stw     r15, CB.f15+4(r6)
    stw     r16, CB.f16+4(r6)
    stw     r17, CB.f17+4(r6)
    stw     r18, CB.f18+4(r6)
    stw     r19, CB.f19+4(r6)
    stw     r20, CB.f20+4(r6)
    stw     r21, CB.f21+4(r6)
    stw     r22, CB.f22+4(r6)
    stw     r23, CB.f23+4(r6)
    stw     r24, CB.f24+4(r6)
    stw     r25, CB.f25+4(r6)
    stw     r26, CB.f26+4(r6)
    stw     r27, CB.f27+4(r6)
    stw     r28, CB.f28+4(r6)
    stw     r29, CB.f29+4(r6)
    stw     r30, CB.f30+4(r6)
    stw     r31, CB.f31+4(r6)
@nofsave

    mfspr   r9, xer
    stw     r9, CB.XER+4(r6)
    mfctr   r9
    stw     r9, CB.CTR(r6)
    mflr    r9
    stw     r9, CB.LR(r6)

    stw     r10, KDP.ProcState.saveSRR0(r1)

    mfspr   r9, srr0
    stw     r9, KDP.ProcState.saveSRR0(r1)
    mfspr   r9, srr1
    stw     r9, KDP.ProcState.saveSRR1(r1)
    mfspr   r9, hid0
    stw     r9, KDP.ProcState.saveHID0(r1)

@tb mftbu   r9
    stw     r9, KDP.ProcState.saveTBU(r1)
    mftb    r9
    stw     r9, KDP.ProcState.saveTBL(r1)
    mftbu   r8
    lwz     r9, KDP.ProcState.saveTBU(r1)
    cmpw    r8, r9
    bne     @tb

    mfspr   r9, dec
    stw     r9, KDP.ProcState.saveDec(r1)
    mfmsr   r9
    stw     r9, KDP.ProcState.saveMSR(r1)
    mfspr   r9, sdr1
    stw     r9, KDP.ProcState.saveSDR1(r1)

    mfspr   r9, dbat0u
    stw     r9, KDP.ProcState.saveDBAT0u(r1)
    mfspr   r9, dbat0l
    stw     r9, KDP.ProcState.saveDBAT0l(r1)
    mfspr   r9, dbat1u
    stw     r9, KDP.ProcState.saveDBAT1u(r1)
    mfspr   r9, dbat1l
    stw     r9, KDP.ProcState.saveDBAT1l(r1)
    mfspr   r9, dbat2u
    stw     r9, KDP.ProcState.saveDBAT2u(r1)
    mfspr   r9, dbat2l
    stw     r9, KDP.ProcState.saveDBAT2l(r1)
    mfspr   r9, dbat3u
    stw     r9, KDP.ProcState.saveDBAT3u(r1)
    mfspr   r9, dbat3l
    stw     r9, KDP.ProcState.saveDBAT3l(r1)
    mfspr   r9, ibat0u
    stw     r9, KDP.ProcState.saveIBAT0u(r1)
    mfspr   r9, ibat0l
    stw     r9, KDP.ProcState.saveIBAT0l(r1)
    mfspr   r9, ibat1u
    stw     r9, KDP.ProcState.saveIBAT1u(r1)
    mfspr   r9, ibat1l
    stw     r9, KDP.ProcState.saveIBAT1l(r1)
    mfspr   r9, ibat2u
    stw     r9, KDP.ProcState.saveIBAT2u(r1)
    mfspr   r9, ibat2l
    stw     r9, KDP.ProcState.saveIBAT2l(r1)
    mfspr   r9, ibat3u
    stw     r9, KDP.ProcState.saveIBAT3u(r1)
    mfspr   r9, ibat3l
    stw     r9, KDP.ProcState.saveIBAT3l(r1)

    mfsprg  r9, 0
    stw     r9, KDP.ProcState.saveSPRG0(r1)
    mfsprg  r9, 1
    stw     r9, KDP.ProcState.saveSPRG1(r1)
    mfsprg  r9, 2
    stw     r9, KDP.ProcState.saveSPRG2(r1)
    mfsprg  r9, 3
    stw     r9, KDP.ProcState.saveSPRG3(r1)


; Money shot
    stw     r6, KDP.ProcState.saveContextPtr(r1)
    bl      SuspendLoop
    lwz     r1, 4(r1) ; because r1 points to KDP.ProcState.saveReturnAddr

; Count up the MS 4 bits of SRn[VSID] (i.e. 000000-F00000)
    lisori  r8, 0x1000000
    lis     r9, 0
@srin_loop
    subis   r9, r9, 0x1000
    subis   r8, r8, 0x10
    mr.     r9, r9
    mtsrin  r8, r9
    bne     @srin_loop

; Reactivate L1 cache
    mfspr   r9, hid0
    li      r8, 0x800           ; HID0[ICFI] invalidate icache
    ori     r8, r8, 0x200       ; HID0[SPD] disable spec cache accesses
    or      r9, r9, r8
    mtspr   hid0, r9
    isync
    andc    r9, r9, r8          ; now undo that?
    mtspr   hid0, r9
    isync
    ori     r9, r9, 0x8000      ; set HID0[ICE]
    ori     r9, r9, 0x4000      ; set HID0[DCE]
    mtspr   hid0, r9
    isync

; Reactivate L2 cache
    lwz     r26, KDP.ProcInfo.ProcessorFlags(r1)
    andi.   r26, r26, 1 << NKProcessorInfo.hasL2CR
    beq     @skipl2
    lwz     r8, KDP.ProcInfo.ProcessorL2DSize(r1)
    mr.     r8, r8
    beq     @skipl2

    mfspr   r9, hid0
    rlwinm  r9, r9, 0, ~0x00100000
    mtspr   hid0, r9
    isync

    lwz     r9, KDP.ProcState.saveL2CR(r1)
    mtspr   l2cr, r9
    sync
    isync
    lis     r8, 0x20            ; set L2CR[L2I] to invalidate L2 cache
    or      r8, r9, r8
    mtspr   l2cr, r8
    sync
    isync

@l2spin
    mfspr   r8, l2cr
    slwi.   r8, r8, 31          ; wait for LS (?reserved) it to come up
    bne     @l2spin

    mfspr   r8, l2cr
    lisori  r9, ~0x00200000     ; unset bit 6 (reserved?)
    and     r8, r8, r9
    mtspr   l2cr, r8
    sync

    mfspr   r8, hid0
    oris    r8, r8, 0x0010      ; set HID0[DOZE]
    mtspr   hid0, r8
    isync

    mfspr   r8, l2cr
    oris    r8, r8, 0x8000      ; set L2CR[L2E]
    mtspr   l2cr, r8
    sync
    isync
@skipl2

; Restore heaps of state...
    lwz     r6, KDP.ProcState.saveContextPtr(r1)
    lwz     r9, CB.CR+4(r6)
    mtcr    r9
    lwz     r9, CB.CTR(r6)
    mtctr   r9
    lwz     r9, CB.LR(r6)
    mtlr    r9
    lwz     r9, CB.XER+4(r6)
    mtxer   r9
    lwz     r9, KDP.ProcState.saveSRR0(r1)
    mtsrr0  r9
    lwz     r9, KDP.ProcState.saveSRR1(r1)
    mtsrr1  r9

    lwz     r0, CB.r0+4(r6)
    lwz     r1, CB.r1+4(r6)
    lwz     r2, CB.r2+4(r6)
    lwz     r3, CB.r3+4(r6)
    lwz     r4, CB.r4+4(r6)
    lwz     r5, CB.r5+4(r6)
    lwz     r6, CB.r6+4(r6)
    lwz     r7, CB.r7+4(r6)
    lwz     r8, CB.r8+4(r6)
    lwz     r9, CB.r9+4(r6)
    lwz     r10, CB.r10+4(r6)
    lwz     r11, CB.r11+4(r6)
    lwz     r12, CB.r12+4(r6)
    lwz     r13, CB.r13+4(r6)
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

    andi.   r8, r11, MsrFP
    beq     @nofload
    lwz     r9, CB.FPSCR+4(r6)
    mtfsf   0xFF, f9
    lfd     f0, CB.f0+4(r6)
    lfd     f1, CB.f1+4(r6)
    lfd     f2, CB.f2+4(r6)
    lfd     f3, CB.f3+4(r6)
    lfd     f4, CB.f4+4(r6)
    lfd     f5, CB.f5+4(r6)
    lfd     f6, CB.f6+4(r6)
    lfd     f7, CB.f7+4(r6)
    lfd     f8, CB.f8+4(r6)
    lfd     f9, CB.f9+4(r6)
    lfd     f10, CB.f10+4(r6)
    lfd     f11, CB.f11+4(r6)
    lfd     f12, CB.f12+4(r6)
    lfd     f13, CB.f13+4(r6)
    lfd     f14, CB.f14+4(r6)
    lfd     f15, CB.f15+4(r6)
    lfd     f16, CB.f16+4(r6)
    lfd     f17, CB.f17+4(r6)
    lfd     f18, CB.f18+4(r6)
    lfd     f19, CB.f19+4(r6)
    lfd     f20, CB.f20+4(r6)
    lfd     f21, CB.f21+4(r6)
    lfd     f22, CB.f22+4(r6)
    lfd     f23, CB.f23+4(r6)
    lfd     f24, CB.f24+4(r6)
    lfd     f25, CB.f25+4(r6)
    lfd     f26, CB.f26+4(r6)
    lfd     f27, CB.f27+4(r6)
    lfd     f28, CB.f28+4(r6)
    lfd     f29, CB.f29+4(r6)
    lfd     f30, CB.f30+4(r6)
    lfd     f31, CB.f31+4(r6)
@nofload

    lwz     r9, KDP.ProcState.saveHID0(r1)
    ori     r9, r9, 0x8000      ; re-enable HID0[ICE]
    ori     r9, r9, 0x4000      ; re-enable HID0[DCE]
    mtspr   hid0, r9
    sync
    isync

    lwz     r9, KDP.ProcState.saveTBU(r1)
    mtspr   tbu, r9
    lwz     r9, KDP.ProcState.saveTBL(r1)
    mtspr   tbl, r9
    lwz     r9, KDP.ProcState.saveDEC(r1)
    mtspr   dec, r9

    lwz     r9, KDP.ProcState.saveMSR(r1)
    mtmsr   r9
    sync
    isync

    lwz     r9, KDP.ProcState.saveSDR1(r1)
    mtspr   sdr1, r9

    lwz     r9, KDP.ProcState.saveSPRG0(r1)
    mtsprg  0, r9
    lwz     r9, KDP.ProcState.saveSPRG1(r1)
    mtsprg  1, r9
    lwz     r9, KDP.ProcState.saveSPRG2(r1)
    mtsprg  2, r9
    lwz     r9, KDP.ProcState.saveSPRG3(r1)
    mtsprg  3, r9

    lwz     r9, KDP.ProcState.saveDBAT0u(r1)
    mtspr   dbat0u, r9
    lwz     r9, KDP.ProcState.saveDBAT0l(r1)
    mtspr   dbat0l, r9
    lwz     r9, KDP.ProcState.saveDBAT1u(r1)
    mtspr   dbat1u, r9
    lwz     r9, KDP.ProcState.saveDBAT1l(r1)
    mtspr   dbat1l, r9
    lwz     r9, KDP.ProcState.saveDBAT2u(r1)
    mtspr   dbat2u, r9
    lwz     r9, KDP.ProcState.saveDBAT2l(r1)
    mtspr   dbat2l, r9
    lwz     r9, KDP.ProcState.saveDBAT3u(r1)
    mtspr   dbat3u, r9
    lwz     r9, KDP.ProcState.saveDBAT3l(r1)
    mtspr   dbat3l, r9
    lwz     r9, KDP.ProcState.saveIBAT0u(r1)
    mtspr   ibat0u, r9
    lwz     r9, KDP.ProcState.saveIBAT0l(r1)
    mtspr   ibat0l, r9
    lwz     r9, KDP.ProcState.saveIBAT1u(r1)
    mtspr   ibat1u, r9
    lwz     r9, KDP.ProcState.saveIBAT1l(r1)
    mtspr   ibat1l, r9
    lwz     r9, KDP.ProcState.saveIBAT2u(r1)
    mtspr   ibat2u, r9
    lwz     r9, KDP.ProcState.saveIBAT2l(r1)
    mtspr   ibat2l, r9
    lwz     r9, KDP.ProcState.saveIBAT3u(r1)
    mtspr   ibat3u, r9
    lwz     r9, KDP.ProcState.saveIBAT3l(r1)
    mtspr   ibat3l, r9

; Back to userspace with no complaints
    li      r3, 0
    b       ReturnFromInt

SuspendLoop ; the guts of 'PowSuspend'
    mflr    r9
    stw     r9, KDP.ProcState.saveReturnAddr(r1)
    stw     r1, KDP.ProcState.saveKernelDataPtr(r1)

    addi    r9, r1, KDP.ProcState.saveReturnAddr
    lis     r0, 0
    nop
    stw     r9, 0(0)
    lisori  r9, 'Lars'
    stw     r9, 4(0)

    mfspr   r9, hid0
    andis.  r9, r9, 0x0020      ; mask: only HID0[SLEEP]
    mtspr   hid0, r9

    mfmsr   r8
    oris    r8, r8, 0x0004      ; set MSR[POW] (just in r8 for now)
    mfspr   r9, hid0
    ori     r9, r9,  0x8000     ; set HID0[ICE]
    mtspr   hid0, r9

; Some arcane code below. The important parts:
; 1. Sleep.
; 2. In the morning, load r1 from physical addr 0, and jump to the ptr in 0(r1).
; 3. That ptr was saveReturnAddr, so saveKernelDataPtr is at 4(r1).
    bl      @l
@l  mflr    r9
    addi    r9, r9, @zerotbl-@l
    lisori  r1, 0xcafebabe
    b       @fatloop
    _align  8
@fatloop
    sync
    mtmsr   r8                  ; sleep now by setting MSR[POW]
    isync
    cmpwi   r1, 0
    beq     @fatloop            ; keep r1 zeroed (for no good reason?)
    lwz     r0, 0(r9)
    andi.   r1, r1, 0
    b       @fatloop
    _align  8
@zerotbl
    dcb.b   16, 0

########################################################################
; Throttles instructions to reduce CPU heat without changing frequency
; (New with G3)
PowSetICCR ; newICCR r5
    mtspr   ICCR, r5
    lisori  r3, 0
    b       ReturnFromInt

########################################################################
; Selector 11
PowInfiniteLoop
    b       *
