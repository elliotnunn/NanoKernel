; Rarely-used interrupt handlers

InstStorageInt
    bl      LoadInterruptRegisters

    andis.  r8, r11, 0x4020             ; Not in HTAB || Bad seg reg
    beq     @already_in_htab

    stmw    r14, KDP.r14(r1)
    mr      r27, r10
    bl      PutPTE
    bne     @illegal_address            ; Could not find in SegMap

    mfsprg  r24, 3
    mfmsr   r14
    _ori    r15, r14, MsrDR
    addi    r23, r1, KDP.VecTblMemRetry
    mtsprg  3, r23
    mr      r19, r10
    mtmsr   r15
    isync
    lbz     r23, 0(r19)
    sync
    mtmsr   r14
    isync
    mtsprg  3, r24
    lmw     r14, KDP.r14(r1)
    b       ReturnFromInt

@illegal_address
    lmw     r14, KDP.r14(r1)
    li      r8, ecInstPageFault
    blt     Exception
    li      r8, ecInstInvalidAddress
    b       Exception

@already_in_htab
    andis.  r8, r11, 0x800              ; Illegal access to legal EA?
    li      r8, ecInstSupAccessViolation
    bne     Exception
    li      r8, ecInstHardwareFault
    b       Exception

########################################################################

MachineCheckInt
    bl      LoadInterruptRegisters
    li      r8, ecMachineCheck
    b       Exception
