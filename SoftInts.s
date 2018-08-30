; "Program" and related interrupts

kSoftIntAlign equ 5

########################################################################

    _align kSoftIntAlign
KCallRunAlternateContext ; CB r3, flags r4
; For the native CB pointers, maintain a 4-entry log-phys cache in KDP
    and.    r8, r4, r13
    lwz     r9, KDP.NCBCacheLA0(r1)
    rlwinm  r8, r3, 0, 0, 25
    cmpw    cr1, r8, r9
    bne     ReturnFromInt

    lwz     r9, KDP.NCBCachePA0(r1)
    bne     cr1, @search_cache
@searched_cache ; r9 now contains a physical ContextBlock ptr

; Use Exceptions code to get into the alternate context
    addi    r8, r1, KDP.VecTblAlternate             ; different external interrupt handling
    mtsprg  3, r8
    lwz     r8, KDP.EmuTrapTableLogical(r1)
    mtcrf   crMaskFlags, r7                         ; why restore kernel condition regs?
    rlwinm  r7, r7, 0, ~maskExceptionNum            ; no exception when we get back to sys
    stw     r8, CB.IntraState.HandlerReturn+4(r9)

    stw     r9, KDP.ContextPtr(r1)                  ; now use Exceptions code
    b       SwitchContext                           ; old_cb r6, new_cb r9

@search_cache
    lwz     r9, KDP.NCBCacheLA1(r1)
    cmpw    cr1, r8, r9
    beq     cr1, @slot1
    lwz     r9, KDP.NCBCacheLA2(r1)
    cmpw    cr1, r8, r9
    beq     cr1, @slot2
    lwz     r9, KDP.NCBCacheLA3(r1)
    cmpw    cr1, r8, r9
    beq     cr1, @slot3

; cache miss
    stmw    r14, KDP.r14(r1)

    cmpw    cr1, r8, r6
    beq     cr1, @fail

    mr      r27, r8
    addi    r29, r1, KDP.BatRanges + 0xa0
    bl      GetPhysical
    clrlwi  r23, r8, 20
    beq     @fail

    cmplwi  r23, 0x0d00
    mr      r9, r8
    mr      r8, r31
    ble     @contiguous

    addi    r27, r27, 0x1000
    addi    r29, r1, KDP.BatRanges + 0xa0
    bl      GetPhysical
    beq     @fail

    subi    r31, r31, 0x1000
    xor     r23, r8, r31
    rlwinm. r23, r23, 0, 25, 22
    bne     @fail ; because physical pages are discontiguous
@contiguous

    clrlwi  r23, r31, 30
    cmpwi   r23, 3
    rlwimi  r8, r9, 0, 20, 31
    beq     @fail

; physical address lookup succeeded
    lwz     r23, KDP.NKInfo.NCBPtrCacheMissCount(r1)
    addi    r23, r23, 1
    stw     r23, KDP.NKInfo.NCBPtrCacheMissCount(r1)

; populate cache slot 3, then waterfall to @searched_cache
    lmw     r14, KDP.r14(r1)
    stw     r8, KDP.NCBCachePA3(r1)

@slot3 ; so promote to slot 2
    lwz     r8, KDP.NCBCacheLA2(r1)
    stw     r9, KDP.NCBCacheLA2(r1)
    stw     r8, KDP.NCBCacheLA3(r1)
    lwz     r9, KDP.NCBCachePA3(r1)
    lwz     r8, KDP.NCBCachePA2(r1)
    stw     r9, KDP.NCBCachePA2(r1)
    stw     r8, KDP.NCBCachePA3(r1)
    lwz     r9, KDP.NCBCacheLA2(r1)

@slot2 ; so promote to slot 1
    lwz     r8, KDP.NCBCacheLA1(r1)
    stw     r9, KDP.NCBCacheLA1(r1)
    stw     r8, KDP.NCBCacheLA2(r1)
    lwz     r9, KDP.NCBCachePA2(r1)
    lwz     r8, KDP.NCBCachePA1(r1)
    stw     r9, KDP.NCBCachePA1(r1)
    stw     r8, KDP.NCBCachePA2(r1)
    lwz     r9, KDP.NCBCacheLA1(r1)

@slot1 ; so promote to slot 0, save elsewhere, and push on
    lwz     r8, KDP.NCBCacheLA0(r1)
    stw     r9, KDP.NCBCacheLA0(r1)
    stw     r9, KDP.NatContextPtrLogical(r1)
    stw     r8, KDP.NCBCacheLA1(r1)
    lwz     r9, KDP.NCBCachePA1(r1)
    lwz     r8, KDP.NCBCachePA0(r1)
    stw     r9, KDP.NCBCachePA0(r1)
    stw     r8, KDP.NCBCachePA1(r1)

    b       @searched_cache

@fail
    lmw     r14, KDP.r14(r1)
    li      r8, ecTrapInstr
    b       Exception

########################################################################

    _align kSoftIntAlign
KCallResetSystem ; PPC trap 1 (68k RESET instruction)
; If Gary Davidian's skeleton key is inserted then return 
; to userspace with a different MSR instead of resetting
    stmw    r14, KDP.r14(r1)
    xoris   r8, r3, 'Ga'            ; a0/r3 must be 'Gary'
    cmplwi  r8,     'ry'
    bne     @notskeleton
    xoris   r8, r4, 0x0505          ; a1/r4 must be 0x05051956
    cmplwi  r8,     0x1956
    bne     @notskeleton
    andc    r11, r11, r5            ; d0/r5 = msr_clear
    lwz     r8, CB.r7+4(r6)
    or      r11, r11, r8            ; d3/r7 = msr_set
    b       ReturnFromInt
@notskeleton

; This file starts with a Reset label, and is part of the init process
    include 'Reset.s'

########################################################################

    _align kSoftIntAlign
KCallPrioritizeInterrupts
    ; Left side: roll back the interrupt preparation before the int handler repeats is
    ; Right side: jump to the external interrupt handler (PIH or ProgramInt)
    mtsprg  2, r12
    mtsrr0  r10
    mtsrr1  r11
    mtcr    r13
    lwz     r10, CB.r10+4(r6)
    lwz     r11, CB.r11+4(r6)
    lwz     r12, CB.r12+4(r6)
    lwz     r13, CB.r13+4(r6)
    lwz     r7, CB.r7+4(r6)
    lwz     r8, KDP.r1(r1)
                                        mfsprg  r9, 3
                                        lwz     r9, VecTbl.External(r9)
    mtsprg  1, r8
                                        mtlr    r9
    lwz     r8, CB.r8+4(r6)
    lwz     r9, CB.r9+4(r6)
    lwz     r6, KDP.r6(r1)
                                        blrl ; (could this ever fall though to KCallSystemCrash?)

########################################################################

KCallSystemCrash
    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    stw     r3, KDP.r3(r1)
    stw     r4, KDP.r4(r1)
    stw     r5, KDP.r5(r1)

    lwz     r8, CB.r7+4(r6)
    lwz     r9, CB.r8+4(r6)
    stw     r8, KDP.r7(r1)
    stw     r9, KDP.r8(r1)

    lwz     r8, CB.r9+4(r6)
    lwz     r9, CB.r10+4(r6)
    stw     r8, KDP.r9(r1)
    stw     r9, KDP.r10(r1)

    lwz     r8, CB.r11+4(r6)
    lwz     r9, CB.r12+4(r6)
    stw     r8, KDP.r11(r1)
    stw     r9, KDP.r12(r1)

    lwz     r8, CB.r13+4(r6)
    stw     r8, KDP.r13(r1)

    stmw    r14, KDP.r14(r1)

    bl      CrashSoftInts

########################################################################

    _align kSoftIntAlign
ProgramInt
;   (also called when the Alternate Context gets an External Int => Exception)

    ;   Standard interrupt palaver
    mfsprg  r1, 0
    stw     r6, KDP.r6(r1)
    mfsprg  r6, 1
    stw     r6, KDP.r1(r1)
    lwz     r6, KDP.ContextPtr(r1)
    stw     r7, CB.r7+4(r6)
    stw     r8, CB.r8+4(r6)
    stw     r9, CB.r9+4(r6)
    stw     r10, CB.r10+4(r6)
    stw     r11, CB.r11+4(r6)
    stw     r12, CB.r12+4(r6)
    stw     r13, CB.r13+4(r6)

    ;   Compare SRR0 with address of Emulator's KCall trap table
    lwz     r8, KDP.EmuTrapTableLogical(r1)
    mfsrr0  r10
    mfcr    r13
    xor.    r8, r10, r8
    lwz     r7, KDP.Flags(r1)
    mfsprg  r12, 2
    beq     KCallReturnFromExceptionFastPath    ; KCall in Emulator table => fast path
    rlwimi. r7, r7, bGlobalFlagSystem, 0, 0
    cmplwi  cr7, r8, 16 * 4
    bge     cr0, @fromAltContext                ; Alt Context cannot make KCalls; this might be an External Int
    bge     cr7, @notFromEmulatorTrapTable      ; from Emulator but not from its KCall table => do more checks

    ;   SUCCESSFUL TRAP from emulator KCall table
    ;   => Service call then return to link register
    add     r8, r8, r1
    lwz     r11, KDP.NKInfo.NanoKernelCallCounts(r8)
    lwz     r10, KDP.KCallTbl(r8)
    addi    r11, r11, 1
    stw     r11, KDP.NKInfo.NanoKernelCallCounts(r8)
    mtlr    r10
    mr      r10, r12 ; ret addr: LR was saved to SPRG2, SPRG2 to r12 above, r12 to r10 now, r10 to SRR0 to program ctr later
    mfsrr1  r11
    rlwimi  r7, r7, 32-5, 26, 26 ; something about MSR[SE]
    blr

@notFromEmulatorTrapTable ; so check if it is even a trap...
    mfsrr1  r11
    mtcrf   0x70, r11
    bc      BO_IF_NOT, 14, @notTrap

    mfmsr   r9                      ; fetch the instruction to get the "trap number"
    _ori    r8, r9, MsrDR
    mtmsr   r8
    isync
    lwz     r8, 0(r10)
    mtmsr   r9
    isync
    xoris   r8, r8, 0xfff
    cmplwi  cr7, r8, 16             ; only traps 0-15 are allowed
    slwi    r8, r8, 2               ; (for "success" case below)
    bge     cr7, @illegalTrap

    ;   SUCCESSFUL TRAP from outside emulator KCall table
    ;   => Service call then return to following instruction
    add     r8, r8, r1
    lwz     r10, KDP.NKInfo.NanoKernelCallCounts(r8)
    addi    r10, r10, 1
    stw     r10, KDP.NKInfo.NanoKernelCallCounts(r8)
    lwz     r8, KDP.KCallTbl(r8)
    mtlr    r8
    addi    r10, r10, 4             ; continue executing the next instruction
    rlwimi  r7, r7, 32-5, 26, 26    ; something about MSR[SE]
    blr

    ;   Cannot service with a KCall => throw Exception
@fromAltContext                     ; external interrupt, or a (forbidden) KCall attempt
    mfsrr1  r11
    mtcrf   0x70, r11
@notTrap                            ; then it was some other software exception
    bc      BO_IF, 12, Emulate
    bc      BO_IF+1, 13, Emulate
    bc      BO_IF, 11, @floatingPointException
@illegalTrap                        ; because we only allow traps 0-15
    rlwinm  r8, r11, 17, 28, 29 
    addi    r8, r8, 0x4b3
    rlwnm   r8, r8, r8, 28, 31
    b       Exception               ; CLEVER BIT HACKING described below

    ;   SRR1[13]    SRR[14]     Exception
    ;   0           0           ecNoException
    ;   0           1           ecTrapInstr
    ;   1           0           ecPrivilegedInstr
    ;   1           1           9 (floating-point?)

@floatingPointException
    li      r8, ecFloatException
    bc      BO_IF, 15, Exception    ; SRR1[15] set => handler can retry
    addi    r10, r10, 4
    rlwimi  r7, r7, 32-5, 26, 26    ; something about MSR[SE]
    b       Exception               ; SRR1[15] unset => can't retry

########################################################################

    _align kSoftIntAlign
SysCallInt
    bl      LoadInterruptRegisters
    mfmsr   r8
    subi    r10, r10, 4
    rlwimi  r11, r8, 0, 0xFFFF0000
    li      r8, ecSystemCall
    b       Exception

########################################################################

    _align kSoftIntAlign
TraceInt ; here because of MSR[SE/BE], possibly thanks to ContextFlagTraceWhenDone
    bl      LoadInterruptRegisters
    li      r8, ecInstTrace
    b       Exception

########################################################################

    _align kSoftIntAlign
IgnoreSoftInt ; Used to probe CPU features at init time
    mfsrr0  r1
    addi    r1, r1, 4
    mtsrr0  r1
    mfsprg  r1, 2
    mtlr    r1
    mfsprg  r1, 1
    rfi
