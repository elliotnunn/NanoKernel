MRException
; Exception was mid-MemRetry, so save MemRetry state to resume later
; MR registers to save: r17 (MR status)
;                       r18 (EA)
;                       r19 (EA of byte after memory)
;                       r20/r21 (loaded data/data to store)
    mtsprg  3, r24

    lwz     r9, KDP.Enables(r1)
    extrwi  r23, r17, 5, 26                 ; extract accessLen field
    rlwnm.  r9, r9, r8, 0, 0                ; BGE taken if exception disabled

    bcl     BO_IF, mrChangedRegInEWA, ReloadChangedMemRetryRegs

    lwz     r6, KDP.ContextPtr(r1)

    _ori    r7, r16, ContextFlagMemRetryErr
    neg     r23, r23
    mtcrf   crMaskFlags, r7
    add     r19, r19, r23                   ; convert r19 from end address back to start address??
    insrwi  r7, r8, 8, 0                    ; ec code -> high byte of flags

    slwi    r8, r8, 2                       ; increment counter
    add     r8, r8, r1
    lwz     r9, KDP.NKInfo.ExceptionCauseCounts(r8)
    addi    r9, r9, 1
    stw     r9, KDP.NKInfo.ExceptionCauseCounts(r8)

    ; Move regs from KDP to ContextBlock
    lwz     r8, KDP.r7(r1)
    stw     r8, CB.r7+4(r6)
    lwz     r8, KDP.r8(r1)
    stw     r8, CB.r8+4(r6)
    lwz     r8, KDP.r9(r1)
    stw     r8, CB.r9+4(r6)
    lwz     r8, KDP.r10(r1)
    stw     r8, CB.r10+4(r6)
    lwz     r8, KDP.r11(r1)
    stw     r8, CB.r11+4(r6)
    lwz     r8, KDP.r12(r1)
    stw     r8, CB.r12+4(r6)
    lwz     r8, KDP.r13(r1)
    stw     r8, CB.r13+4(r6)

    bge     RunSystemContext                ; Alt Context has left exception disabled => Sys Context
    ;fall through                           ; exception enabled => run userspace handler

########################################################################

ExceptionCommon
; (MR)Exception that is Enabled (i.e. not being auto-forced to System)
    stw     r10, CB.FaultSrcPC+4(r6)            ; Save r10/SRR0, r12/LR, r3, r4
    stw     r12, CB.FaultSrcLR+4(r6)
    stw     r3, CB.FaultSrcR3+4(r6)
    stw     r4, CB.FaultSrcR4+4(r6)

    lwz     r8, KDP.Enables(r1)                     ; Save Enables & Flags, inc ContextFlagMemRetryErr      
    stw     r7, CB.IntraState.Flags(r6)
    stw     r8, CB.IntraState.Enables(r6)

                                                    ; Use IntraState because context handles its own error
    li      r8, 0                                   ; Enables=0 (any exceptions in handler go to System)
    lwz     r10, CB.IntraState.Handler+4(r6)        ; SRR0 = handler addr
    lwz     r4, CB.IntraState.HandlerArg+4(r6)      ; r4 = arbitrary second argument
    lwz     r3, KDP.SysContextPtrLogical(r1)        ; r3 = ContextBlock ptr
    bc      BO_IF, bGlobalFlagSystem, @sys
    lwz     r3, KDP.NCBCacheLA0(r1)
@sys
    lwz     r12, KDP.EmuTrapTableLogical(r1)        ; r12/LR = address of KCallReturnFromException trap

    bcl     BO_IF, bContextFlagMemRetryErr, SaveFailingMemRetryState

    rlwinm  r7, r7, 0, 29, 15                       ; unset flags 16-28
    stw     r8, KDP.Enables(r1)
    rlwimi  r11, r7, 0, 20, 23                      ; threfore unset MSR[FE0/SE/BE/FE1]

    b       ReturnFromInt

########################################################################

ReloadChangedMemRetryRegs
    lwz     r0, KDP.r0(r1)
    lwz     r2, KDP.r2(r1)
    lwz     r3, KDP.r3(r1)
    lwz     r4, KDP.r4(r1)
    lwz     r5, KDP.r5(r1)
    blr

SaveFailingMemRetryState
    stw     r17, CB.IntraState.MemRetStatus+4(r6)
    stw     r20, CB.IntraState.MemRetData(r6)
    stw     r21, CB.IntraState.MemRetData+4(r6)
    stw     r19, CB.IntraState.MemRetEAR+4(r6)
    stw     r18, CB.IntraState.MemRetEA+4(r6)
    lmw     r14, KDP.r14(r1)
    blr

########################################################################

    _align 5
KCallReturnFromExceptionFastPath
    lwz     r11, KDP.NKInfo.NanoKernelCallCounts(r1)
    mr      r10, r12
    addi    r11, r11, 1
    stw     r11, KDP.NKInfo.NanoKernelCallCounts(r1)
    mfsrr1  r11
    rlwimi  r7, r7, 32+bMsrSE-bContextFlagTraceWhenDone, ContextFlagTraceWhenDone

KCallReturnFromException
    cmplwi  cr1, r3, 1                          ; exception handler return value
    blt     cr1, @dispose
    mtcrf   crMaskFlags, r7
    beq     cr1, @propagate

; If handler returns an exception cause code 2-255, "force" this exception to the System Context.
    subi    r8, r3, 32
    lwz     r9, KDP.NKInfo.ExceptionForcedCount(r1)
    cmplwi  r8, 256-32
    addi    r9, r9, 1
    stw     r9, KDP.NKInfo.ExceptionForcedCount(r1)
    insrwi  r7, r3, 8, 0
    blt     RunSystemContext
    li      r8, ecTrapInstr
    b       Exception                           ; (error if number is > max exception number)

; If handler returns 0 (System Context must always do this), return to userspace.
@dispose
    lwz     r8, CB.IntraState.Flags(r6)         ; Restore Context flags (inc exception number?)
    lwz     r10, CB.FaultSrcPC+4(r6)
    rlwimi  r7, r8, 0, maskExceptionNum | maskContextFlags ; preserve global flags
    lwz     r8, CB.IntraState.Enables(r6)
    rlwimi  r11, r7, 0, maskMsrFlags
    stw     r8, KDP.Enables(r1)
    andi.   r8, r11, MsrFE0 + MsrFE1            ; check: are floating-pt exceptions enabled?

    lwz     r12, CB.FaultSrcLR+4(r6)            ; restore LR/r3/r4
    lwz     r3, CB.FaultSrcR3+4(r6)
    lwz     r4, CB.FaultSrcR4+4(r6)

    bnel    ThawFPU

    addi    r9, r6, CB.IntraState               ; If MemRetry was interrupted, resume it.

    b       ReturnFromInt

; If handler returns 1, "propagate" this exception to the System Context
; (When we get back to the Alternate Context, it will be as if the exception was disposed.)
@propagate
    lwz     r9, KDP.NKInfo.ExceptionPropagateCount(r1)
    lwz     r8, CB.IntraState.Flags(r6)
    addi    r9, r9, 1
    stw     r9, KDP.NKInfo.ExceptionPropagateCount(r1)
    lwz     r10, CB.FaultSrcPC+4(r6)
    rlwimi  r7, r8, 0, maskExceptionNum | maskContextFlags ; preserve global flags
    lwz     r8, CB.IntraState.Enables(r6)
    mtcrf   crMaskContextFlags, r7
    rlwimi  r11, r7, 0, maskMsrFlags
    stw     r8, KDP.Enables(r1)

    lwz     r12, CB.FaultSrcLR+4(r6)            ; restore LR/r3/r4
    lwz     r3, CB.FaultSrcR3+4(r6)
    lwz     r4, CB.FaultSrcR4+4(r6)

    bc      BO_IF_NOT, bContextFlagMemRetryErr, RunSystemContext
    stmw    r14, KDP.r14(r1)                    ; When we *do* get back to this context,
    lwz     r17, CB.IntraState.MemRetStatus+4(r6);make sure MemRetry state can be resumed
    lwz     r20, CB.IntraState.MemRetData(r6)   ; from InterState
    lwz     r21, CB.IntraState.MemRetData+4(r6)
    lwz     r19, CB.IntraState.MemRetEAR+4(r6)
    lwz     r18, CB.IntraState.MemRetEA+4(r6)
    b       RunSystemContext

########################################################################

;   BEFORE
;       PowerPC exception vector saved r1/LR in SPRG1/2 and
;       jumped where directed by the VecTbl pointed to by
;       SPRG3. That function bl'ed here.
;
;   AFTER
;       Reg     Contains            Original saved in
;       ---------------------------------------------
;        r0     (itself)
;        r1     KDP                 SPRG1
;        r2     (itself)                    
;        r3     (itself)
;        r4     (itself)
;        r5     (itself)
;        r6     ContextBlock        EWA
;        r7     Flags               ContextBlock
;        r8     KDP                 ContextBlock
;        r9     (scratch CB ptr)    ContextBlock
;       r10     SRR0                ContextBlock
;       r11     SRR1                ContextBlock
;       r12     LR                  ContextBlock
;       r13     CR                  ContextBlock

LoadInterruptRegisters
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
    mfsrr0  r10
    mfcr    r13
    lwz     r7, KDP.Flags(r1)
    mfsprg  r12, 2
    mfsrr1  r11
    blr

########################################################################

Exception
    lwz     r9, KDP.Enables(r1)
    mtcrf   crMaskFlags, r7

    rlwnm.  r9, r9, r8, 0, 0                ; BLT taken if exception enabled

    insrwi  r7, r8, 8, 0                    ; Exception code to hi byte of Flags

    slwi    r8, r8, 2                       ; Increment counter, easy enough
    add     r8, r8, r1
    lwz     r9, KDP.NKInfo.ExceptionCauseCounts(r8)
    addi    r9, r9, 1
    stw     r9, KDP.NKInfo.ExceptionCauseCounts(r8)

    blt     ExceptionCommon             ; exception enabled => run userspace handler
    ;fall through                           ; Alt Context has left exception disabled => Sys Context

########################################################################

RunSystemContext
; Switch back from the Alternate context to the 68k Emulator
    lwz     r9, KDP.SysContextPtr(r1)       ; System ("Emulator") ContextBlock

    addi    r8, r1, KDP.VecTblSystem        ; System VecTbl
    mtsprg  3, r8

    bcl     BO_IF, bGlobalFlagSystem, CrashExceptions ; System Context already running!

########################################################################

SwitchContext ; old_cb r6, new_cb r9
; Run the System or Alternate Context
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

    lwz     r8, KDP.OtherContextDEC(r1)
    mfdec   r31
    cmpwi   r8, 0
    stw     r31, KDP.OtherContextDEC(r1)
    mtdec   r8
    blel    ResetDEC ; to r8

    lwz     r8, CB.InterState.Flags(r9)             ; r8 is the new Flags variable
    stw     r9, KDP.ContextPtr(r1)
    xoris   r7, r7, GlobalFlagSystem >> 16          ; flip Emulator flag
    rlwimi  r11, r8, 0, maskMsrFlags
    mr      r6, r9                                  ; change the magic ContextBlock register
    rlwimi  r7, r8, 0, maskContextFlags             ; change bottom half of flags only

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

    stwcx.  r0, 0, r1

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

########################################################################

ReturnFromInt
; (if ContextFlagMemRetryErr && ContextFlagResumeMemRetry, pass KernelState ptr in r9)
    andi.   r8, r7, ContextFlagTraceWhenDone | ContextFlagMemRetryErr
    bnel    @special_cases          ; Keep rare cases out of the hot path

    stw     r7, KDP.Flags(r1)       ; Save kernel flags for next interrupt
    mtlr    r12                     ; Restore user SPRs from kernel GPRs
    mtsrr0  r10
    mtsrr1  r11
    mtcr    r13
    lwz     r10, CB.r10+4(r6)       ; Restore user GPRs from ContextBlock
    lwz     r11, CB.r11+4(r6)
    lwz     r12, CB.r12+4(r6)
    lwz     r13, CB.r13+4(r6)
    lwz     r7, CB.r7+4(r6)
    lwz     r8, CB.r8+4(r6)
    lwz     r9, CB.r9+4(r6)
    lwz     r6, KDP.r6(r1)          ; Restore last two registers from EWA
    lwz     r1, KDP.r1(r1)
    rfi                             ; Go

@special_cases
    mtcrf   crMaskFlags, r7
    bc      BO_IF_NOT, bContextFlagMemRetryErr, @no_memretry            ; If MemRetry had to be paused for an exception
    rlwinm  r7, r7, 0, ~ContextFlagMemRetryErr                          ; which is now finished, finish MemRetry.
    bc      BO_IF, bContextFlagResumeMemRetry, @resume_memretry
    rlwinm  r7, r7, 0, ~ContextFlagTraceWhenDone
    b       @justreturn

@no_memretry
    bc      BO_IF_NOT, bContextFlagTraceWhenDone, @justreturn           ; If this current interrupt was raised when
    rlwinm  r7, r7, 0, ~ContextFlagTraceWhenDone                        ; every instruction should be followed by a
    stw     r7, KDP.Flags(r1)                                           ; Trace exception, then raise one.
    li      r8, ecInstTrace
    b       Exception

@justreturn
    blr

@resume_memretry ; Pick up where an MRException left off, now that the Exception has been disposed.
    stw     r7, KDP.Flags(r1)

    stw     r0, KDP.r0(r1)
    stw     r2, KDP.r2(r1)
    stw     r3, KDP.r3(r1)
    stw     r4, KDP.r4(r1)
    stw     r5, KDP.r5(r1)

    lwz     r8, CB.r7+4(r6)
    stw     r8, KDP.r7(r1)
    lwz     r8, CB.r8+4(r6)
    stw     r8, KDP.r8(r1)
    lwz     r8, CB.r9+4(r6)
    stw     r8, KDP.r9(r1)
    lwz     r8, CB.r10+4(r6)
    stw     r8, KDP.r10(r1)
    lwz     r8, CB.r11+4(r6)
    stw     r8, KDP.r11(r1)
    lwz     r8, CB.r12+4(r6)
    stw     r8, KDP.r12(r1)
    lwz     r8, CB.r13+4(r6)
    stw     r8, KDP.r13(r1)

    stmw    r14, KDP.r14(r1)

    lwz     r17, KernelState.MemRetStatus+4(r9) ; Get the MR state from IntraState (if context was never switched)
    lwz     r20, KernelState.MemRetData(r9)     ; or InterState (if exception was propagated to System Context and
    lwz     r21, KernelState.MemRetData+4(r9)   ; we are now switching back to Alternate Context).
    lwz     r19, KernelState.MemRetEAR+4(r9)
    lwz     r18, KernelState.MemRetEA+4(r9)
    rlwinm  r16, r7, 0, ~ContextFlagMemRetryErr

    lwz     r25, KDP.MRBase(r1)         ; MRRestab is indexed by the first arg of MROptab?
    extrwi. r22, r17, 4, 27             ; 
    add     r19, r19, r22               ; Correct r19 (EA) by adding len from r17
    rlwimi  r25, r17, 7, 25, 30
    lhz     r26, MRRestab-MRBase(r25)

    insrwi  r25, r19, 3, 28             ; Set Memtab alignment modulus
    stw     r16, KDP.Flags(r1)
    rlwimi  r26, r26, 8, 8, 15          ; First byte of MRRestab is for cr3/cr4
    insrwi  r25, r17, 4, 24             ; len and load/store from second arg of MROptab?
    mtcrf   0x10, r26                   ; Set CR3
    lha     r22, MRMemtab-MRBase(r25)   ; Jump to MRMemtab...

    addi    r23, r1, KDP.VecTblMemRetry
    add     r22, r22, r25
    mfsprg  r24, 3
    mtlr    r22
    mtsprg  3, r23
    mfmsr   r14
    _ori    r15, r14, MsrDR
    mtmsr   r15
    isync
    rlwimi  r25, r26, 2, 22, 29         ; Second byte of MRRestab is a secondary routine
    bnelr
    b       MRDoSecondary

########################################################################

ResetDEC ; to r8
    lis     r31, 0x7FFF
    mtdec   r31
    mtdec   r8
    blr
