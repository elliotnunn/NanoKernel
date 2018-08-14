; CPU exceptions while the kernel's MemRetry code is running

MRDataStorageInt ; Consult DSISR and the page table to decide what to do
    mfdsisr r31                     ; Check DSISR for simple HTAB miss
    andis.  r28, r31, 0xC030        ; (bits 0/1/10/11)
    mfsprg  r1, 1
    mfdar   r27
    bne     @possible_htab_miss

    andis.  r28, r31, 0x0800        ; Illegal data access (else crash!)
    addi    r29, r1, KDP.CurDBAT0
    bnel    GetPhysical             ; Get LBAT or lower PTE
    li      r28, 0x43               ; Filter Writethru and Protection bits
    and     r28, r31, r28
    cmpwi   cr7, r28, 0x43
    beql    CrashMRInts             ; Not illegal data access => Crash
    mfsprg  r28, 2
    mtlr    r28
    bne     cr7, @access_exception  ; Any filtered bit unset => Exception

    mfsrr0  r28                     ; Writethru and Protection bits set => ROM write nop
    addi    r28, r28, 4
    lwz     r26, KDP.NKInfo.QuietWriteCount(r1)
    mtsrr0  r28
    addi    r26, r26, 1
    stw     r26, KDP.NKInfo.QuietWriteCount(r1)

@return
    extrwi  r26, r25, 8, 22         ; Signal to some MemRetry code?
    rfi

@access_exception
    andi.   r28, r31, 3
    li      r8, ecDataSupAccessViolation
    beq     MRException

    cmpwi   r28, 3
    li      r8, ecDataWriteViolation
    beq     MRException             ; Nobody allowed to write => Exception
    li      r8, ecDataSupWriteViolation
    b       MRException             ; Supervisor allowed to write => Exception

@possible_htab_miss
    andis.  r28, r31, 0x8010        ; Check for DataAccess Interrupt or ec[io]wx
    bne     MRHardwareFault         ; Either of those => big trouble

    bl      PutPTE                  ; HTAB miss => fill HTAB
    mfsprg  r28, 2                  ; (restore lr)
    mtlr    r28
    beq     @return                 ; HTAB success => RFI
    li      r8, ecDataPageFault
    blt     MRException             ; Fault => Exception
    li      r8, ecDataInvalidAddress
    b       MRException             ; Bad address => Exception

MRMachineCheckInt                   ; Always gives HW fault
    mfsprg  r1, 1
    lwz     r27, KDP.HtabLastEA(r1)

    subf    r28, r19, r27           ; Delete last HTAB entry if suspicious
    cmpwi   r28, -16                ; (i.e. within 16b of MemRetried EA)
    blt     @no_htab_del
    cmpwi   r28, 16
    bgt     @no_htab_del

    lwz     r28, KDP.NKInfo.HashTableDeleteCount(r1)
    lwz     r29, KDP.HtabLastPTE(r1)
    addi    r28, r28, 1
    stw     r28, KDP.NKInfo.HashTableDeleteCount(r1)
    li      r28, 0
    stw     r28, 0(r29)
    sync
    tlbie   r27
    sync
@no_htab_del

MRHardwareFault                     ; Can come from a DSI or a Machine Check
    cmplw   r10, r19
    li      r8, ecDataHardwareFault
    bne     MRException

    mtsprg  3, r24
    lmw     r14, KDP.r14(r1)
    li      r8, ecInstHardwareFault
    b       Exception
