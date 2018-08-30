; Primary and secondary functions referenced by MROptab

MRPriCrash
    bl      Crash
MRSecException
    b       MRSecException2

########################################################################

MRPriSTFSx
    rlwinm  r17, r17, 0,16,10

MRPriSTFSUx
    crclr   cr7_so
    b       MRDoTableSTFD

MRPriSTFDx
    rlwinm  r17, r17, 0,16,10

MRPriSTFDUx
    crset   cr7_so

MRDoTableSTFD
; This table is of the form:
;   stfd <reg>, KDP.FloatScratch(r1)
;   b MRDoneTableSTFD

    clrrwi  r19, r25, 10
    rlwimi  r19, r17, 14,24,28
    addi    r19, r19, STFDTable-MRBase
    mtlr    r19
    rlwimi  r14, r11, 0,18,18
    mtmsr   r14
    isync
    blr

MRDoneTableSTFD
    ori     r11, r11, 0x2000
    lwz     r20, KDP.FloatScratch(r1)
    lwz     r21, KDP.FloatScratch+4(r1)
    bso     cr7, MRPriUpdLoad
    extrwi  r23, r20, 11,1
    cmpwi   r23, 0x380
    insrwi  r20, r20, 27,2
    inslwi  r20, r21, 3,29
    mr      r21, r20
    bgt     MRPriUpdLoad
    cmpwi   r23, 0x36A
    clrrwi  r21, r20, 31
    blt     MRPriUpdLoad
    oris    r20, r20, 0x80
    neg     r23, r23
    clrlwi  r20, r20, 8
    srw     r20, r20, r23
    rlwimi  r21, r20, 31,9,31
    b       MRPriUpdLoad

########################################################################

MRPriSTWBRX
    rlwinm  r28, r17, 13,25,29
    lwbrx   r21, r1, r28
    b       MRPriPlainLoad

MRPriSTHBRX
    rlwinm  r28, r17, 13,25,29
    addi    r21, r1, 2
    lhbrx   r21, r21, r28
    b       MRPriPlainLoad

########################################################################

MRPriUpdStore
    rlwinm  r28, r17, 13,25,29
    lwzx    r21, r1, r28
    b       MRPriUpdLoad

MRPriPlainStore
    rlwinm  r28, r17, 13,25,29
    lwzx    r21, r1, r28

MRPriPlainLoad
    rlwinm  r17, r17, 0,16,10

MRPriUpdLoad
    extrwi. r22, r17, 4,27
    add     r19, r18, r22

########################################################################

MRPriDone
    clrrwi  r25, r25, 10
    insrwi  r25, r19, 3,28
    insrwi  r25, r17, 4,24
    lha     r22, MRMemtab-MRBase(r25)
    addi    r23, r1, KDP.VecTblMemRetry
    add     r22, r22, r25
    mtlr    r22
    mtsprg  3, r23
    mtmsr   r15
    isync
    insrwi  r25, r26, 8,22
    bnelr
    b       MRDoSecondary

########################################################################

MRStore22 ; Fast return paths from MemAccess code
    srwi    r23, r21, 16
    sth     r23, -4(r19)
    addi    r17, r17, -4
    sth     r21, -2(r19)
    b       MRDoSecondary
MRLoad22
    lhz     r23, -4(r19)
    addi    r17, r17, -4
    insrwi  r21, r23, 16, 0
MRLoad2
    lhz     r23, -2(r19)
    insrwi  r21, r23, 16, 16

MRDoSecondary
    bl      SetMSRFlush
    rlwinm. r28, r17, 18,25,29 ; get the block-offset of rA
    mtlr    r25
    cror    cr0_eq, cr0_eq, mrSuppressUpdate
    mtsprg  3, r24
    beqlr
    crset   mrChangedRegInEWA       ; do this only if it's a non-zero register and we aren't suppressing update
    stwx    r18, r1, r28
    blr

########################################################################

MRSecLoadExt
    extsh   r21, r21

MRSecLoad
    rlwinm  r28, r17, 13,25,29
    crset   mrChangedRegInEWA
    stwx    r21, r1, r28

########################################################################

MRSecDone
    andi.   r23, r16, ContextFlagTraceWhenDone    ; Time to return from interrupt
    addi    r10, r10, 4
    mtsrr0  r10
    mtsrr1  r11
    bne     @trace                      ; Is a Trace flagged?
    mtlr    r12

    bc      BO_IF_NOT, mrChangedRegInEWA, @load_ewa_registers
    mtcr    r13
    lmw     r2, KDP.r2(r1)
    lwz     r0, KDP.r0(r1)
    lwz     r1, KDP.r1(r1)
    rfi
@load_ewa_registers                     ; Only load changed registers
    mtcr    r13
    lmw     r10, KDP.r10(r1)
    lwz     r1, KDP.r1(r1)
    rfi

@trace                                  ; Jump to Trace int handler
    mfsprg  r24, 3
    mtsprg  2, r12
    rlwinm  r16, r16, 0, ~ContextFlagTraceWhenDone
    lwz     r12, VecTbl.Trace(r24)
    stw     r16, KDP.Flags(r1)
    mtcr    r13
    mtlr    r12
    lmw     r2, KDP.r2(r1)
    lwz     r0, KDP.r0(r1)
    lwz     r1, KDP.r1(r1)
    mtsprg  1, r1
    blrl

########################################################################

MRSecLHBRX
    slwi    r21, r21, 16

MRSecLWBRX
    rlwinm  r28, r17, 13,25,29
    crset   mrChangedRegInEWA
    stwbrx  r21, r1, r28
    b       MRSecDone

########################################################################

MRSecLFSu
    clrrwi  r20, r21, 31
    xor.    r21, r20, r21
    beq     MRSecLFDu
    rlwinm. r23, r21, 16,17,24
    addi    r23, r23, 0x80
    rlwimi  r20, r21, 29,5,31
    extsh   r23, r23
    rlwimi  r20, r21, 0,1,1
    slwi    r21, r21, 29
    addi    r23, r23, -0x4080
    rlwimi  r20, r23, 0,2,4
    bne     MRSecLFDu
    srwi    r21, r21, 20
    insrwi  r21, r20, 20,0
    cntlzw  r23, r21
    slw     r21, r21, r23
    neg     r23, r23
    rlwimi  r20, r21, 21,12,31
    addi    r23, r23, 0x380
    slwi    r21, r21, 21
    insrwi  r20, r23, 11,1

MRSecLFDu
; This table is of the form:
;    lfd <reg>, KDP.FloatScratch(r1)
;    b MRSecDone
    clrrwi  r23, r25, 10
    rlwimi  r23, r17, 14,24,28
    addi    r23, r23, LFDTable-MRBase
    mtlr    r23
    stw     r20, KDP.FloatScratch(r1)
    stw     r21, KDP.FloatScratch+4(r1)
    rlwimi  r14, r11, 0,18,18
    mtmsr   r14
    isync
    ori     r11, r11, 0x2000
    blr

########################################################################

MRSecLMW
    rlwinm. r28, r17, 13,25,29
    rlwinm  r23, r17, 18,25,29
    cmpw    cr7, r28, r23
    addis   r17, r17, 0x20
    beq     loc_E68
    beq     cr7, loc_E6C

loc_E68
    stwx    r21, r1, r28

loc_E6C
    cmpwi   r28, 0x7C
    li      r22, 9
    insrwi  r17, r22, 6,26
    addi    r19, r19, 4
    bne     MRPriDone
    b       MRSecDone

MRSecSTMW
    addis   r17, r17, 0x20
    rlwinm. r28, r17, 13,25,29
    beq     MRSecDone
    lwzx    r21, r1, r28
    li      r22, 8
    insrwi  r17, r22, 6,26
    addi    r19, r19, 4
    b       MRPriDone

########################################################################

MRPriDCBZ                      ; Zero four 8b chunks of the cache blk
    lhz     r21, KDP.ProcInfo.DataCacheBlockSize(r1) ; r19 = address of chunk to zero
    neg     r21, r21
    and     r19, r18, r21
    b       MRComDCBZ           ; (for use by this code only)

MRSecDCBZ
    lhz     r21, KDP.ProcInfo.DataCacheBlockSize(r1)
    subi    r21, r21, 8
    and.    r22, r19, r21
    clrrwi  r19, r19, 3         ; MemAccess code decrements this reg
    beq     MRSecDone           ; Zeroed all foun chunks -> done!

MRComDCBZ
    li      r22, 0x10           ; Set 8 bytes (? set bit 27)
    insrwi. r17, r22, 6,26
    addi    r19, r19, 8         ; Align ptr to right hand size of chunk
    li      r20, 0              ; Contents = zeros
    li      r21, 0
    b       MRPriDone       ; Go, then come back to MRSecDCBZ

########################################################################

MRSecLWARX
    rlwinm  r28, r17, 13,25,29
    crset   mrChangedRegInEWA
    stwx    r21, r1, r28
    stwcx.  r21, r1, r28
    b       MRSecDone

MRSecSTWCX
    stwcx.  r0, 0, r1
    mfcr    r23
    rlwinm  r23, r23, 0,3,1
    rlwimi  r13, r23, 0,0,3
    b       MRSecDone

########################################################################

MRSecRedoNoTrace ; Rerun the (cache) instruction, but not its Trace Exception
    rlwinm  r16, r16, 0, ~(ContextFlagTraceWhenDone | ContextFlagMemRetryErr)
    subi    r10, r10, 4
    stw     r16, KDP.Flags(r1)
    b       MRSecDone

########################################################################

MRSecException2
    li      r8, ecDataInvalidAddress
    b       MRException

########################################################################

MRPriSTSWI
    addi    r22, r27, -0x800
    extrwi  r22, r22, 5,16
    b       loc_F2C

MRPriSTSWX
    mfxer   r22
    andi.   r22, r22, 0x7F
    addi    r22, r22, -1
    beq     MRSecDone

loc_F2C
    rlwimi  r17, r22, 4,21,25
    not     r22, r22
    insrwi  r17, r22, 2,4
    mr      r19, r18
    b       loc_1008

MRSecStrStore
    andi.   r22, r17, 0x7C0
    addis   r28, r17, 0x20
    rlwimi  r17, r28, 0,6,10
    addi    r17, r17, -0x40
    bne     loc_1008
    b       MRSecDone

########################################################################

MRPriLSWI
    addi    r22, r27, -0x800
    extrwi  r22, r22, 5,16
    addis   r28, r27, 0x3E0
    rlwimi  r17, r28, 22,16,20
    b       loc_F80

MRPriLSWX
    mfxer   r22
    andi.   r22, r22, 0x7F
    rlwimi  r17, r27, 0,16,20
    addi    r22, r22, -1
    beq     MRSecDone

loc_F80
    andis.  r23, r17, 0x1F
    rlwimi  r17, r22, 4,21,25
    not     r22, r22
    insrwi  r17, r22, 2,4
    mr      r19, r18
    bne     loc_1070
    rlwimi  r17, r17, 5,11,15
    b       loc_1070

MRSecLSWix
    andi.   r22, r17, 0x7C0
    rlwinm  r28, r17, 13,25,29
    bne     loc_1044
    rlwinm  r22, r17, 9,27,28
    slw     r21, r21, r22
    b       loc_1044

########################################################################

MRPriLSCBX
    mfxer   r22
    andi.   r22, r22, 0x7F
    rlwimi  r17, r27, 0,16,20
    insrwi  r17, r27, 1,3
    addi    r22, r22, -1
    beq     MRSecDone
    andis.  r23, r17, 0x1F
    rlwimi  r17, r22, 4,21,25
    not     r22, r22
    insrwi  r17, r22, 2,4
    mr      r19, r18
    bne     loc_10C8
    rlwimi  r17, r17, 5,11,15
    b       loc_10C8

MRSecLSCBX
    rlwinm. r22, r17, 28,25,29
    rlwinm  r28, r17, 13,25,29
    bne     loc_109C
    rlwinm  r23, r17, 9,27,28
    slw     r21, r21, r23
    b       loc_109C

########################################################################

loc_1008
    andi.   r23, r17, 0x7C0
    rlwinm  r28, r17, 13,25,29
    lwzx    r21, r1, r28
    li      r22, 8
    insrwi  r17, r22, 6,26
    addi    r19, r19, 4
    bne     MRPriDone
    rlwinm  r22, r17, 9,27,28
    srw     r21, r21, r22
    extrwi  r22, r17, 2,4
    neg     r22, r22
    add     r19, r19, r22
    addi    r22, r22, 4
    insrwi. r17, r22, 5,26
    b       MRPriDone

loc_1044
    rlwinm  r23, r17, 18,25,29
    cmpw    cr7, r28, r23
    rlwinm  r23, r17, 23,25,29
    cmpw    cr6, r28, r23
    beq     cr7, loc_1060
    beq     cr6, loc_1060
    stwx    r21, r1, r28

loc_1060
    addis   r28, r17, 0x20
    rlwimi  r17, r28, 0,6,10
    addi    r17, r17, -0x40
    beq     MRSecDone

loc_1070
    andi.   r23, r17, 0x7C0
    li      r22, 9
    insrwi  r17, r22, 6,26
    addi    r19, r19, 4
    bne     MRPriDone
    extrwi  r22, r17, 2,4
    neg     r22, r22
    add     r19, r19, r22
    addi    r22, r22, 4
    insrwi. r17, r22, 5,26
    b       MRPriDone

loc_109C
    rlwinm  r23, r17, 18,25,29
    cmpw    cr7, r28, r23
    rlwinm  r23, r17, 23,25,29
    cmpw    cr6, r28, r23
    beq     cr7, loc_10B8
    beq     cr6, loc_10B8
    stwx    r21, r1, r28

loc_10B8
    addis   r28, r17, 0x20
    rlwimi  r17, r28, 0,6,10
    addi    r17, r17, -0x40
    beq     MRSecDone

loc_10C8
    not     r22, r22
    rlwimi  r22, r17, 6,30,31
    li      r28, 1
    mfxer   r23
    extrwi  r23, r23, 8,16
    srwi    r20, r21, 24
    cmpw    cr7, r20, r23
    add.    r22, r22, r28
    beq     cr7, loc_112C
    beq     loc_112C
    extrwi  r20, r21, 8,8
    cmpw    cr7, r20, r23
    add.    r22, r22, r28
    beq     cr7, loc_112C
    beq     loc_112C
    extrwi  r20, r21, 8,16
    cmpw    cr7, r20, r23
    add.    r22, r22, r28
    beq     cr7, loc_112C
    beq     loc_112C
    clrlwi  r20, r21, 24
    cmpw    cr7, r20, r23
    add.    r22, r22, r28
    beq     cr7, loc_112C
    bne     loc_1070

loc_112C
    rlwinm. r28, r17, 0,3,3
    mfxer   r23
    add     r22, r22, r23
    insrwi  r23, r22, 7,25
    mtxer   r23
    beq     MRSecDone
    mfcr    r23
    clrlwi  r23, r23, 30
    insrwi  r13, r23, 4,0
    b       MRSecDone
