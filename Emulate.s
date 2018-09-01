InitEmulation
    li      r23, 0
    _ori    r23, r23, EmAlways1
    _ori    r23, r23, EmAlways2

; Ignore Program Interrupts so we can blindly hit SPRs
    lwz     r21, KDP.CodeBase(r1)
    lwz     r20, KDP.VecTblSystem.Program(r1)
    _kaddr  r21, r21, IgnoreSoftInt
    stw     r21, KDP.VecTblSystem.Program(r1)

; Test MMCR0 (perf monitor) and related registers
    li      r18, 0
    mtspr   mmcr0, r18      ; Monitor Mode Control Reg
    not     r19, r18
    mfspr   r19, mmcr0      ; (set and get register;
    xor     r17, r18, r19   ; if r18 = r19, register works)
    mtspr   pmc1, r18       ; Perf Mon Counter Reg 1
    not     r19, r18
    mfspr   r19, pmc1
    xor     r19, r18, r19
    or      r17, r17, r19
    mtspr   pmc2, r18       ; Perf Mon Counter Reg 2
    not     r19, r18
    mfspr   r19, pmc2
    xor     r19, r18, r19
    or      r17, r17, r19
    mtspr   sia, r18        ; Sampled Instruction Reg
    not     r19, r18
    mfspr   r19, sia
    xor     r19, r18, r19
    or.     r17, r17, r19
    bne     @nommcr0
    _ori    r23, r23, EmHasMMCR0
@nommcr0
    mtspr   sda, r18        ; Sampled Data Reg
    not     r19, r18
    mfspr   r19, sda
    xor     r19, r18, r19
    or.     r17, r17, r19
    bne     @nosda
    _ori    r23, r23, EmHasSDA
@nosda

; Test MMCR1 (perf monitor) and related registers
mmcr1 equ 956
pmc3 equ 957
pmc4 equ 958
    mtspr   mmcr1, r18      ; Perf Mon Control Reg (Extra)
    not     r19, r18
    mfspr   r19, mmcr1      ; (set and get register;
    xor     r17, r18, r19   ; if r18 = r19, register works)
    mtspr   pmc3, r18       ; Perf Mon Counter Reg 1
    not     r19, r18
    mfspr   r19, pmc3
    xor     r19, r18, r19
    or      r17, r17, r19
    mtspr   pmc4, r18       ; Perf Mon Counter Reg 2
    not     r19, r18
    mfspr   r19, pmc4
    xor     r19, r18, r19
    or.     r17, r17, r19
    bne     @nommcr1
    _ori    r23, r23, EmHasMMCR1
@nommcr1

; Clean up and save flags
    stw     r20, KDP.VecTblSystem.Program(r1)
    stw     r23, KDP.InstEmControl(r1)

; Use long division to calculate TB tick -> RTC nanosec scaling factor
    lisori  r20, 0x80587ff3         ; r20/r21 = 64-bit dividend
    lisori  r21, 0xd62611e3         ; (why 9248282520051913187)

    lwz     r19, KDP.ProcInfo.DecClockRateHz(r1)
    cntlzw  r23, r19                ; r19 = divisor = left-justified clock rate
    slw     r19, r19, r23           ; (maximises use of mantissa)

    cmpw    cr1, r20, r19
    addi    r23, r23, 2
    xor.    r24, r24, r24
    bge     cr1, @slowdecrementer
    subi    r23, r23, 1
@divloop
    cmpwi   cr1, r20, 0             ; compare shifted dividend to divisor
    slwi    r20, r20, 1             ; (divisor fits if cr1.lt or !cr2.lt)
    inslwi  r20, r21, 1, 31
    cmplw   cr2, r20, r19
    slwi.   r24, r24, 1

    slwi    r21, r21, 1             ; shift the quotient (r21) and set a bit if necessary
    blt     cr1, @definitely
    blt     cr2, @definitelynot
@slowdecrementer
@definitely
    subf    r20, r19, r20
    ori     r24, r24, 1
@definitelynot

    bge     @divloop                ; repeat until dividend is exhausted

; Save that scaling factor, plus exponent in convenient formats
    stw     r24, KDP.InstEmTimebaseScale(r1)
    stb     r23, KDP.InstEmControl(r1)
    li      r21, 32
    subf    r21, r23, r21
    stb     r21, KDP.InstEmControl+3(r1)
    blr

########################################################################

    MACRO ; compare reg to 5-bit-chunk-swapped SPR number
    _csprnm &myCR, &myReg, &myNum
    cmplwi &myCR, &myReg, (&myNum >> 5) | ((&myNum << 5) & %1111100000)
    ENDM

    MACRO ; MFSPR. with record bit ("dot")
    mfspr_ &myGPR, &mySPR
    mfspr &myGPR, &mySPR
    org *-1
    dc.b $A7
    ENDM

    MACRO ; MTSPR. with record bit ("dot")
    mtspr_ &mySPR, &myGPR
    mtspr &mySPR, &myGPR
    org *-1
    dc.b $A7
    ENDM

Emulate
    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    stw     r3, KDP.r3(r1)
    stw     r4, KDP.r4(r1)
    stw     r5, KDP.r5(r1)
    stmw    r14, KDP.r14(r1)

    mr      r16, r7

    lwz     r7, CB.r7+4(r6)
    stw     r7, KDP.r7(r1)
    lwz     r8, CB.r8+4(r6)
    stw     r8, KDP.r8(r1)
    lwz     r9, CB.r9+4(r6)
    stw     r9, KDP.r9(r1)

    lwz     r23, CB.r10+4(r6)
    stw     r23, KDP.r10(r1)
    lwz     r23, CB.r11+4(r6)
    stw     r23, KDP.r11(r1)
    lwz     r23, CB.r12+4(r6)
    stw     r23, KDP.r12(r1)
    lwz     r23, CB.r13+4(r6)
    stw     r23, KDP.r13(r1)

    addi    r22, r6, CB.MQ + 4

    lwz     r6, KDP.r6(r1)

    lwz     r23, KDP.NKInfo.EmulatedUnimpInstCount(r1)
    lwz     r25, KDP.MRBase(r1)
    addi    r23, r23, 1
    stw     r23, KDP.NKInfo.EmulatedUnimpInstCount(r1)

    mfmsr   r14
    _ori    r15, r14, MsrDR
    mtmsr   r15
    isync
    lwz     r27, 0(r10)
    mtmsr   r14
    isync

    srwi    r23, r27, 26
    cmpwi   cr6, r23, 9         ; dozi (POWER)
    cmpwi   cr0, r23, 22        ; rlmi (POWER)
    cmpwi   cr1, r23, 31        ; X-form

    lwz     r20, KDP.InstEmControl(r1)
    _mvbit0 r21, 14, r16, bContextFlagEmulateAll
    neg     r21, r21                        ; EmAllow* (8-14) = ContextFlagEmulateAll
    _mvbit  r21, 16, r16, 30                ; 16   = runtimeflag[30]
    or      r21, r21, r20                   ; or with cap flags
    rlwimi  r21, r27, 0, 21, 31             ; insert X-form opcode

    _mvbit  r16, bContextFlagTraceWhenDone, r16, bMsrSE

    rlwinm  r17, r27, 13, 0x7C  ; rS/rD idx * 4         6-10  *4
    rlwinm  r18, r27, 18, 0x7C  ; second reg idx * 4    11-15 *4 (could also be left half of spr code)

    beq     cr6, EmDOZI
    mtcrf   crMaskFlags, r21 ; cr2-cr7

    rlwinm  r19, r27, 23, 0x7C  ; third reg idx (or lower SPR num) * 4

    beq     cr0, DoRLMI
    bne     cr1, @cannotemulate

;X-form: Consult X-table entry indexed by LOWER 5 bits of X-opcode
    rlwinm  r21, r27, 2, 24, 28             ; Each X-table entry contains a 32 bit mask
    add     r21, r21, r25                   ; specifying which combinations of UPPER
    lwz     r20, XTable-MRBase(r21)         ; 5 bits may be emulated.
    extrwi  r23, r27, 5, 21
    lwz     r21, XTable+4-MRBase(r21)       ; Second word of entry points to routine.
    rotlw.  r20, r20, r23
    add     r21, r21, r25
    mtlr    r21
    bltlr                                   ; (CR0.LT if mask bit is set)

@cannotemulate
    ble     cr1, RealIllegalInst
    lisori  r20, %1010101010101100101010100000000
    rotlw.  r20, r20, r23
    blt     Em10101

########################################################################

RealIllegalInst
    mtcrf   %01110000, r11 ; cr1-cr3
    li      r8, ecInvalidInstr
    bc      BO_IF_NOT, bMsrPOW, IllegalInstFail

PrivIllegalInst
    mtcrf   %00001111, r11 ; cr4-cr7
    li      r8, ecInvalidInstr
    bc      BO_IF_NOT, bMsrPR, @sup
    li      r8, ecPrivilegedInstr
@sup

IllegalInstFail
    lwz     r9, KDP.NKInfo.EmulatedUnimpInstCount(r1)
    lmw     r14, KDP.r14(r1)
    subi    r9, r9, 1
    stw     r9, KDP.NKInfo.EmulatedUnimpInstCount(r1)
    lwz     r6, KDP.ContextPtr(r1)
    lwz     r7, KDP.Flags(r1)
    b       Exception

########################################################################

XTable

    MACRO ; Here are some macros for the X-form extended opcode table
    xtabRow &myLeftFlags, &myLabel
    DC.L &myLeftFlags, &myLabel - MRBase
    ENDM

    MACRO
    xtabClr
    xtabRow 0, RealIllegalInst
    ENDM

; This table is indexed by the most-significant (i.e. right-hand) 5 bits
; of the X-form extended opcode. Each entry contains a 32-bit mask
; specifying which combinations of least-siginificant 5 bits can be
; emulated, and also an offset to the emulation routine.

;            .00000* .01000* .10000* .11000*
;             .00001* .01001* .10001* .11001*    -- Mask bits for
;              .00010* .01010* .10010* .11010*      MS part of XO
;               .00011* .01011* .10011* .11011*
;                .00100* .01100* .10100* .11100*
;                 .00101* .01101* .10101* .11101*     Table indexed by
;                  .00110* .01110* .10110* .11110*    LS part of XO
;                   .00111* .01111* .10111* .11111*         |

    xtabClr                                             ; *00000
    xtabClr                                             ; *00001
    xtabClr                                             ; *00010   
    xtabClr                                             ; *00011
    xtabClr                                             ; *00100
    xtabClr                                             ; *00101
    xtabClr                                             ; *00110
    xtabClr                                             ; *00111
    xtabRow %00000000100100010000000010010001, Em01000  ; *01000 doz abs nabs dozo abso nabso
    xtabClr                                             ; *01001
    xtabClr                                             ; *01010
    xtabRow %00010000001100000001000000110000, Em01011  ; *01011 mul div divs mulo divo divso
    xtabClr                                             ; *01100
    xtabClr                                             ; *01101
    xtabClr                                             ; *01110
    xtabClr                                             ; *01111
    xtabClr                                             ; *10000
    xtabClr                                             ; *10001
    xtabClr                                             ; *10010
    xtabRow %00000000001100101000000000000000, Em10011  ; *10011 mfspr mftb mtspr clcs
    xtabClr                                             ; *10100
    xtabRow %00000000100000001010000000000000, Em10101  ; *10101 lscbx lswx lswi
    xtabClr                                             ; *10110
    xtabRow %01010101010101000101010100000010, Em10111  ; *10111 lwzux lbzux stwux stbux lhzux lhaux sthux lfsux lfdux stfsux stfdux 11110*
    xtabRow %00001111000000000000111100001100, Em11000  ; *11000 slq sliq sllq slliq srq sriq srlq srliq sraq sraiq
    xtabRow %00001010000000001000101000001000, Em11001  ; *11001 sle sleq rrib sre sreq srea
    xtabClr                                             ; *11010
    xtabClr                                             ; *11011
    xtabClr                                             ; *11100
    xtabRow %10000000000000001000000000000000, Em11101  ; *11101 maskg maskir
    xtabClr                                             ; *11110
    xtabClr                                             ; *11111

########################################################################

EmChangeRegRecordSetMQ            ; Return pathways
    stw     r20, 0(r22)
EmChangeRegRecord
    bc      BO_IF_NOT, 31, EmChangeRegOnly
    mfcr    r23
    rlwimi  r13, r23, 0, 0xF0000000
EmChangeRegOnly
    stwx    r21, r1, r17
    b       MRSecDone

########################################################################

Em01000 ;              (21----30)
; 011111...............0100001000. doz
; 011111...............0101101000. abs
; 011111...............0111101000. nabs
; 011111...............1100001000. dozo
; 011111...............1101101000. abso
; 011111...............1111101000. nabso
    bc      BO_IF_NOT, bEmAllowHarmless, RealIllegalInst
    lwzx    r18, r1, r18
    bge     cr6, FDP_14EC
    bgt     cr5, FDP_14B0
    mr.     r21, r18
    crxor   cr5_so, cr5_so, cr0_lt
    bns     cr5, EmChangeRegRecord
    neg.    r21, r18
    b       EmChangeRegRecord

FDP_14b0
    li      r21, 0
    addo.   r21, r18, r21
    crxor   cr5_so, cr5_so, cr0_lt
    bns     cr5, EmChangeRegRecord
    nego.   r21, r18
    b       EmChangeRegRecord

EmDOZI
    mtcrf   0x3f, r21
    bc      BO_IF_NOT, bEmAllowHarmless, RealIllegalInst
    lwzx    r18, r1, r18
    extsh   r19, r27
    cmpw    cr1, r19, r18
    subf    r21, r21, r21
    blt     cr1, EmChangeRegOnly
    subf    r21, r18, r19
    b       EmChangeRegOnly

FDP_14ec
    lwzx    r19, r1, r19
    bgt     cr5, FDP_1508
    cmpw    cr1, r19, r18
    sub.    r21, r21, r21
    blt     cr1, EmChangeRegRecord
    sub.    r21, r19, r18
    b       EmChangeRegRecord


FDP_1508
    cmpw    cr1, r19, r18
    subo.   r21, r21, r21
    blt     cr1, EmChangeRegRecord
    subo.   r21, r19, r18
    b       EmChangeRegRecord

########################################################################

Em01011 ;              (21----30)
; 011111...............0001101011. mul
; 011111...............0101001011. div
; 011111...............0101101011. divs
; 011111...............1001101011. mulo
; 011111...............1101001011. divo
; 011111...............1101101011. divso
    bc      BO_IF_NOT, bEmAllowMQ, RealIllegalInst
    lwzx    r19, r1, r19
    lwzx    r18, r1, r18
    bne     cr5, FDP_16B8
    cmpwi   cr1, r19, 0
    bgt     cr6, FDP_1548
    lwz     r24, 0(r22)
    srwi    r21, r24, 31
    add.    r21, r21, r18
    bne     FDP_1590
    mr      r18, r24


FDP_1548
    cmpwi   r19, -1
    bgt     cr5, FDP_1574
    beq     FDP_1568
    beq     cr1, FDP_1580
    divw    r21, r18, r19


FDP_155c
    mullw   r20, r21, r19
    sub.    r20, r18, r20
    b       EmChangeRegRecordSetMQ


FDP_1568
    neg     r21, r18
    sub.    r20, r18, r18
    b       EmChangeRegRecordSetMQ


FDP_1574
    divwo   r21, r18, r19
    beq     FDP_1568
    bne     cr1, FDP_155C


FDP_1580
    rlwinm  r23, r18, 2, 30, 30
    subi    r21, r23, 1
    mr.     r20, r18
    b       EmChangeRegRecordSetMQ


FDP_1590
    mfxer   r26         ; XER = 1
    beq     cr1, FDP_1698
    cmpwi   r19, 0
    cmpwi   cr1, r18, 0
    crxor   cr1_so, cr0_lt, cr1_lt
    bge     FDP_15AC
    neg     r19, r19


FDP_15ac
    bge     cr1, FDP_15B8
    subfic  r24, r24, 0
    subfze  r18, r18


FDP_15b8
    cmplw   r18, r19
    bge     FDP_1698
    cntlzw  r21, r19
    xor     r18, r18, r24
    slw     r19, r19, r21
    rotlw   r18, r18, r21
    slw     r24, r24, r21
    xor     r18, r18, r24
    srwi    r23, r19, 16
    divwu   r20, r18, r23
    mullw   r23, r20, r23
    sub     r18, r18, r23
    slwi    r18, r18, 16
    inslwi  r18, r24, 16, 16
    slwi    r24, r24, 16
    clrlwi  r23, r19, 16
    mullw   r23, r20, r23
    subc    r18, r18, r23
    subfe.  r23, r23, r23
    add     r24, r24, r20
    bge     FDP_161C


FDP_160c
    addc    r18, r18, r19
    addze.  r23, r23
    subi    r24, r24, 1
    blt     FDP_160C


FDP_161c
    srwi    r23, r19, 16
    divwu   r20, r18, r23
    mullw   r23, r20, r23
    sub     r18, r18, r23
    slwi    r18, r18, 16
    inslwi  r18, r24, 16, 16
    slwi    r24, r24, 16
    clrlwi  r23, r19, 16
    mullw   r23, r20, r23
    subc    r18, r18, r23
    subfe.  r23, r23, r23
    add     r24, r24, r20
    bge     FDP_1660


FDP_1650
    addc    r18, r18, r19
    addze.  r23, r23
    subi    r24, r24, 1
    blt     FDP_1650


FDP_1660
    srw     r20, r18, r21
    mr.     r21, r24
    bge     cr1, FDP_1670
    neg     r20, r20


FDP_1670
    bns     cr1, FDP_1678
    neg.    r21, r21


FDP_1678
    ble     cr5, FDP_168C
    crxor   cr0_lt, cr0_lt, cr1_so
    rlwinm  r26, r26, 0, 2, 0
    bge     FDP_168C
    oris    r26, r26, 0xC000


FDP_168c
    mtxer   r26         ; XER = 1
    mr.     r20, r20
    b       EmChangeRegRecordSetMQ


FDP_1698
    ble     cr5, FDP_16A0
    oris    r26, r26, 0xC000


FDP_16a0
    mtxer   r26         ; XER = 1
    not     r21, r18
    srwi    r23, r18, 31
    mr.     r20, r24
    add     r21, r23, r21
    b       EmChangeRegRecordSetMQ


FDP_16b8
    mulhw   r21, r18, r19
    bgt     cr5, FDP_16C8
    mullw.  r20, r18, r19
    b       EmChangeRegRecordSetMQ


FDP_16c8
    mullwo. r20, r18, r19
    b       EmChangeRegRecordSetMQ

########################################################################

Em10011 ;              (21----30)
; 011111...............0101010011. mfspr
; 011111...............0101110011. mftb
; 011111...............0111010011. mtspr
; 011111...............1000010011. clcs
    bc      BO_IF, 25, @mftb
    bc      BO_IF, 21, EmCLCS

; Branch block for the most common move-from-user-spr cases
    cmpwi   r18, 64                 ; (test upper bit: means priv'd)
    cmpwi   cr1, r18, %00000 * 4
    cmpwi   cr6, r18, %00001 * 4
    bc      BO_IF, 23, @movetospr   ; (sidle away if mtspr'ing, or
    bge     @movefrompriv           ; if this is a privileged SPR;
    crclr   cr0_lt                  ; clear the CR bit we just used!)
    beq     cr1, @mfmq
    beq     cr6, @mfxer
    cmpwi   cr1, r18, %00101 * 4
    cmpwi   cr6, r18, %00110 * 4
    beq     cr1, @mfrtc_
    beq     cr6, @mfdec
    cmpwi   cr1, r18, %01000 * 4
    cmpwi   cr6, r18, %01001 * 4
    beq     cr1, @mflr
    beq     cr6, @mfctr
    cmpwi   cr6, r18, %00100 * 4
    lwzx    r18, r1, r18
    lwzx    r19, r1, r19
    add.    r21, r18, r19
    beq     cr6, @mfrtc_
    bc      BO_IF_NOT, bEmAllowUsrSPRs, RealIllegalInst
    b       EmRecordOnly

@mfmq
    bc      BO_IF_NOT, bEmAllowMQ, RealIllegalInst
    lwz     r21, 0(r22)
    b       EmChangeRegRecord

@mfxer
    bc      BO_IF_NOT, bEmAllowUsrSPRs, RealIllegalInst
    mtcrf   %10000000, r13
    mfspr_  r21, xer
    b       EmChangeRegRecord

@mfrtc_ ; upper or lower
    bc      BO_IF_NOT, bEmAllowRTC, RealIllegalInst
@retrytb
    mftbu   r20
    mftb    r21
    mftbu   r23
    cmplw   cr1, r23, r20
    bne-    cr1, @retrytb

    lwz     r23, KDP.InstEmTimebaseScale(r1)
    lbz     r18, KDP.InstEmControl(r1)
    lbz     r19, KDP.InstEmControl+3(r1)
    mullw   r22, r20, r23
    mulhwu  r24, r21, r23
    add     r22, r22, r24

    bc      BO_IF_NOT, 26, @bit26clear

    cmplw   cr1, r22, r24
    srw     r22, r22, r19
    mulhwu  r21, r20, r23
    bge+    cr1, @nocarry
    addi    r21, r21, 1
@nocarry
    slw     r21, r21, r18
    add     r21, r21, r22
    b       EmChangeRegRecord

@bit26clear ; should never happen
    mullw   r21, r21, r23
    srw     r21, r21, r19
    slw     r22, r22, r18
    add     r21, r21, r22
    lisori  r23, 1000000000
    mulhwu  r21, r21, r23
    b       EmChangeRegRecord

@mfdec
    bc      BO_IF_NOT, bEmAllowDEC, RealIllegalInst
    mfdec   r21         ; DEC = 22
    b       EmChangeRegRecord

@mflr
    bc      BO_IF_NOT, bEmAllowUsrSPRs, RealIllegalInst
    mtcrf   %10000000, r13
    mtlr    r12         ; LR = 8
    mfspr_  r21, lr
    b       EmChangeRegRecord

@mfctr
    bc      BO_IF_NOT, bEmAllowUsrSPRs, RealIllegalInst
    mtcrf   %10000000, r13
    mfspr_  r21, ctr
    b       EmChangeRegRecord


@movefrompriv
    mtcrf   %10000000, r13
    extrwi  r19, r27, 10, 11
    _csprnm cr1, r19, pvr
    beq     cr1, @mfpvr
    bc      BO_IF_NOT, bEmHasMMCR0, PrivIllegalInst
    _csprnm cr1, r19, mmcr0
    beq     cr1, @mfmmcr0
    _csprnm cr1, r19, pmc1
    beq     cr1, @mfpmc1
    _csprnm cr1, r19, pmc2
    beq     cr1, @mfpmc2
    _csprnm cr1, r19, sia
    beq     cr1, @mfsia
    bc      BO_IF_NOT, bEmHasSDA, @nosda
    _csprnm cr1, r19, sda
    beq     cr1, @mfsda
@nosda
    bc      BO_IF_NOT, bEmHasMMCR1, PrivIllegalInst
    _csprnm cr1, r19, mmcr1
    beq     cr1, @mfmmcr1
    _csprnm cr1, r19, pmc3
    beq     cr1, @mfpmc3
    _csprnm cr1, r19, pmc4
    beq     cr1, @mfpmc4
    b       PrivIllegalInst

@mfpvr
    ble     cr4, PrivIllegalInst
    mfspr_  r21, pvr
    b       EmChangeRegRecord
@mfmmcr0
    mfspr_  r21, mmcr0
    b       EmChangeRegRecord
@mfpmc1
    mfspr_  r21, pmc1
    b       EmChangeRegRecord
@mfpmc2
    mfspr_  r21, pmc2
    b       EmChangeRegRecord
@mfsia
    mfspr_  r21, sia
    b       EmChangeRegRecord
@mfmmcr1
    mfspr_  r21, mmcr1
    b       EmChangeRegRecord
@mfpmc3
    mfspr_  r21, pmc3
    b       EmChangeRegRecord
@mfpmc4
    mfspr_  r21, pmc4
    b       EmChangeRegRecord
@mfsda
    mfspr_  r21, sda
    b       EmChangeRegRecord

@mftb
    extrwi  r23, r27, 10, 11
    _csprnm cr1, r23, 268
    _csprnm cr6, r23, 269
    cror    cr0_eq, cr1_eq, cr6_eq
    bne     RealIllegalInst
@retryrtc
    mfspr   r20, rtcu
    mfspr   r21, rtcl
    mfspr   r23, rtcu
    xor.    r23, r23, r20
    bne-    @retryrtc
    lisori  r23, 1000000000
    mfspr   r24, MQ
    mullw   r19, r20, r23
    mtspr   MQ, r24
    add     r21, r21, r19
    beq     cr1, EmChangeRegOnly
    cmplw   r21, r19
    mulhwu  r21, r20, r23
    mtspr   MQ, r24
    bge     EmChangeRegOnly
    addi    r21, r21, 1
    b       EmChangeRegOnly


; To illustrate what was done just before jumping here:
;   cmpwi   r18, 64                 ; (test upper bit: means priv'd)
;   cmpwi   cr1, r18, %00000 * 4
;   cmpwi   cr6, r18, %00001 * 4
@movetospr
    lwzx    r17, r1, r17
    bge     @movetopriv
    mr.     r17, r17
    beq     cr1, @mtmq
    bc      BO_IF_NOT, bEmAllowUsrSPRs, RealIllegalInst
    beq     cr6, @mtxer
    cmpwi   cr1, r18, 32
    cmpwi   cr6, r18, 36
    beq     cr1, @mtlr
    beq     cr6, @mtctr
    b       EmRecordOnly


@mtmq
    bc      BO_IF_NOT, bEmAllowMQ, RealIllegalInst
    stw     r17, 0(r22)
    b       EmRecordOnly
@mtxer
    mtcrf   %10000000, r13
    mtspr_  xer, r17
    b       EmRecordOnly
@mtlr
    mtcrf   %10000000, r13
    mr      r12, r17
    mtspr_  lr, r17
    b       EmRecordOnly
@mtctr
    mtcrf   %10000000, r13
    mtspr_  ctr, r17
    b       EmRecordOnly


@movetopriv
    bc      BO_IF_NOT, bEmHasMMCR0, PrivIllegalInst
    mtcrf   %10000000, r13
    extrwi  r19, r27, 10, 11
    _csprnm cr1, r19, 952
    beq     cr1, FDP_1A24
    _csprnm cr1, r19, 953
    beq     cr1, FDP_1A2C
    _csprnm cr1, r19, 954
    beq     cr1, FDP_1A34
    _csprnm cr1, r19, 955
    beq     cr1, FDP_1A3C
    bc      BO_IF_NOT, bEmHasSDA, @nowsda
    _csprnm cr1, r19, 959
    beq     cr1, FDP_1A5C
@nowsda
    bc      BO_IF_NOT, bEmHasMMCR1, PrivIllegalInst
    _csprnm cr1, r19, 956
    beq     cr1, FDP_1A44
    _csprnm cr1, r19, 957
    beq     cr1, FDP_1A4C
    _csprnm cr1, r19, 958
    beq     cr1, FDP_1A54
    b       PrivIllegalInst


FDP_1a24
    mtspr_  mmcr0, r17
    b       EmRecordOnly


FDP_1a2c
    mtspr_  pmc1, r17
    b       EmRecordOnly


FDP_1a34
    mtspr_  pmc2, r17
    b       EmRecordOnly


FDP_1a3c
    mtspr_  sia, r17
    b       EmRecordOnly


FDP_1a44
    mtspr_  mmcr1, r17
    b       EmRecordOnly


FDP_1a4c
    mtspr_  pmc3, r17
    b       EmRecordOnly


FDP_1a54
    mtspr_  pmc4, r17
    b       EmRecordOnly


FDP_1a5c
    mtspr_  sda, r17
    b       EmRecordOnly


EmCLCS ; Compute Cache Line Size, POWER-only (RA selector in bits 11-15)
    bc      BO_IF_NOT, bEmAllowCacheInfo, RealIllegalInst
    extrwi. r18, r27, 4, 12             ; Get low 4 bits of RA selector
    rlwinm  r21, r27, 16, 28, 30        ; CacheTotalSize fields (x101x) are longs!
    cmpwi   cr1, r21, %01010
    addi    r18, r18, @clcstable-MRBase
    lbzx    r18, r25, r18
    addi    r21, r1, KDP.ProcInfo

    beq     cr1, @longfield
    lhzx    r21, r21, r18
    b       EmChangeRegRecord
@longfield
    lwzx    r21, r21, r18
    b       EmChangeRegRecord

@clcstable
    WITH NKProcessorInfo    ; Value of last 4 bits of RA field:
    dc.b    DataCacheLineSize           ; x0000
    dc.b    DataCacheLineSize           ; x0001
    dc.b    DataCacheLineSize           ; x0010
    dc.b    DataCacheLineSize           ; x0011
    dc.b    DataCacheBlockSizeTouch     ; x0100
    dc.b    InstCacheBlockSize          ; x0101
    dc.b    DataCacheBlockSize          ; x0110
    dc.b    CombinedCaches              ; x0111
    dc.b    InstCacheAssociativity      ; x1000
    dc.b    DataCacheAssociativity      ; x1001
    dc.b    InstCacheTotalSize ;long    ; x1010
    dc.b    DataCacheTotalSize ;long    ; x1011
    dc.b    InstCacheLineSize           ; x1100 (arch)
    dc.b    DataCacheLineSize           ; x1101 (arch)
    dc.b    DataCacheLineSize           ; x1110 (arch)
    dc.b    DataCacheLineSize           ; x1111 (arch)
    ENDWITH

########################################################################

Em11001 ;              (21----30)
; 011111...............0010011001. sle
; 011111...............0011011001. sleq
; 011111...............1000011001. rrib
; 011111...............1010011001. sre
; 011111...............1011011001. sreq
; 011111...............1110011001. srea
    lwzx    r19, r1, r19
    clrlwi  r19, r19, 27
    bc      BO_IF, 23, FDP_1B1C

; rrib
    bc      BO_IF_NOT, bEmAllowHarmless, RealIllegalInst
    lwzx    r17, r1, r17
    lis     r23, -32768
    lwzx    r21, r1, r18
    srw     r23, r23, r19
    srw     r17, r17, r19
    b       FDP_1C08

########################################################################

Em11000 ;              (21----30)
; 011111...............0010011000. slq
; 011111...............0010111000. sliq
; 011111...............0011011000. sllq
; 011111...............0011111000. slliq
; 011111...............1010011000. srq
; 011111...............1010111000. sriq
; 011111...............1011011000. srlq
; 011111...............1011111000. srliq
; 011111...............1110011000. sraq
; 011111...............1110111000. sraiq
    bc      BO_IF, 25, @immediateop
    lwzx    r19, r1, r19
    clrlwi  r19, r19, 26
    bc      BO_IF_NOT, 24, FDP_1B1C
    cmpwi   r19, 31
    crnot   cr5_so, cr5_so
    ble     FDP_1B1C
    bc      BO_IF_NOT, bEmAllowMQ, RealIllegalInst
    lwz     r20, 0(r22)
    li      r23, -1
    clrlwi  r19, r19, 27
    bgt     cr5, @FDP_1b0c
    slw     r23, r23, r19
    and.    r21, r20, r23
    b       EmRecordChangeReg


@FDP_1b0c
    srw     r23, r23, r19
    and.    r21, r20, r23
    b       EmRecordChangeReg


@immediateop
    extrwi  r19, r27, 5, 16


FDP_1b1c
    bc      BO_IF_NOT, bEmAllowMQ, RealIllegalInst
    lwzx    r17, r1, r17
    bgt     cr5, FDP_1B64
    slw.    r21, r17, r19
    rotlw   r20, r17, r19
    bge     cr6, EmRecordChangeRegSetMQ
    li      r23, -1
    slw     r23, r23, r19


FDP_1b3c
    lwz     r19, 0(r22)
    andc    r23, r19, r23
    or.     r21, r21, r23
    bns     cr5, EmRecordChangeReg


EmRecordChangeRegSetMQ
    stw     r20, 0(r22)
EmRecordChangeReg
    stwx    r21, r1, r18
EmRecordOnly
    bc      BO_IF_NOT, 31, MRSecDone
    mfcr    r23
    rlwimi  r13, r23, 0, 0xF0000000
    b       MRSecDone


FDP_1b64
    neg     r20, r19
    rotlw   r20, r17, r20
    beq     cr5, FDP_1B84
    srw.    r21, r17, r19
    bge     cr6, EmRecordChangeRegSetMQ
    li      r23, -1
    srw     r23, r23, r19
    b       FDP_1B3C


FDP_1b84
    sraw.   r21, r17, r19
    b       EmRecordChangeRegSetMQ

########################################################################

Em11101 ;              (21----30)
; 011111...............0000011101. maskg
; 011111...............1000011101. maskir
    bc      BO_IF_NOT, bEmAllowHarmless, RealIllegalInst
    lwzx    r19, r1, r19
    lwzx    r17, r1, r17
    bgt     cr5, FDP_1BBC
    li      r21, -1
    sub     r19, r19, r17
    not     r19, r19
    clrlwi  r19, r19, 27
    neg     r17, r17
    slw     r21, r21, r19
    rotlw.  r21, r21, r17
    b       EmRecordChangeReg


FDP_1bbc
    lwzx    r21, r1, r18
    and     r17, r17, r19
    andc    r21, r21, r19
    or.     r21, r21, r17
    b       EmRecordChangeReg


DoRLMI
    bc      BO_IF_NOT, bEmAllowHarmless, RealIllegalInst
    lwzx    r17, r1, r17
    rlwinm  r20, r27, 26, 27, 31
    lwzx    r19, r1, r19
    rlwinm  r21, r27, 31, 27, 31
    li      r23, -0x01
    subf    r21, r20, r21
    not     r21, r21
    clrlwi  r21, r21,  0x1b
    neg     r20, r20
    slw     r23, r23, r21
    lwzx    r21, r1, r18
    rotlw   r23, r23, r20
    rotlw   r17, r17, r19


FDP_1c08
    and     r17, r17, r23
    andc    r21, r21, r23
    or.     r21, r21, r17
    b       EmRecordChangeReg

########################################################################

Em10101 ;              (21----30)
; 011111...............0100010101. lscbx
; 011111...............1000010101. lswx
; 011111...............1001010101. lswi
    bc      BO_IF_NOT, bEmAllowMemRetry, RealIllegalInst
    b       EmulateViaMemRetry

########################################################################

Em10111 ;              (21----30)
; 011111...............0000110111. lwzux
; 011111...............0001110111. lbzux
; 011111...............0010110111. stwux
; 011111...............0011110111. stbux
; 011111...............0100110111. lhzux
; 011111...............0101110111. lhaux
; 011111...............0110110111. sthux
; 011111...............1000110111. lfsux
; 011111...............1001110111. lfdux
; 011111...............1010110111. stfsux
; 011111...............1011110111. stfdux
; 011111...............1111010111. ???
    bgt     cr6, Em10101
    bge     cr4, RealIllegalInst
    b       EmulateViaMemRetry
