; Part of the Init control flow. Really nasty, TBH.

UpdateProcessorInfo
; Overwrite some intrinsic CPU properties in our copied ProcessorInfo
    mfpvr   r12
    stw     r12, KDP.ProcInfo.ProcessorVersionReg(r1)
    srwi    r12, r12, 16
    lwz     r11, KDP.CodeBase(r1)
    addi    r10, r1, KDP.ProcInfo.Ovr
    li      r9, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr

    cmpwi   r12, 1 ; 601
    _kaddr  r11, r11, ProcessorInfoTable
    beq     ChosenProcessorInfo

    cmpwi   r12, 3 ; 603
    addi    r11, r11, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr
    beq     ChosenProcessorInfo

    cmpwi   r12, 4 ; 604
    addi    r11, r11, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr
    beq     ChosenProcessorInfo

    cmpwi   r12, 6 ; 603e
    addi    r11, r11, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr
    beq     ChosenProcessorInfo

    cmpwi   r12, 7 ; 750
    addi    r11, r11, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr
    beq     ChosenProcessorInfo

    cmpwi   r12, 8 ; 750FX
    addi    r11, r11, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr
    beq     ChosenProcessorInfo

    cmpwi   r12, 9 ; ???
    addi    r11, r11, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr
    beq     ChosenProcessorInfo

    cmpwi   r12, 0x54 ; use 750FX again
    subi    r11, r11, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr
    beq     ChosenProcessorInfo

########################################################################

; Locate Page Table (HTAB): r21/r22 = start/size
    mfsdr1  r22
    rlwinm  r21, r22, 0, 0xFFFF0000
    rlwinm  r22, r22, 16, 0x007F0000
    addis   r22, r22, 1

; Locate largest physical RAM Bank: r13/r15 = start/size
    li      r15, 0
    li      r12, NKSystemInfo.MaxBanks
    mtctr   r12
    addi    r10, r1, KDP.SysInfo.EndOfBanks
@bankloop
    lwz     r11, -4(r10)
    lwzu    r12, -8(r10)
    subf    r9, r12, r21
    cmplw   r9, r11
    bge     @nohtabinbank           ; (exclude HTAB from figured size)
    mr      r11, r9
@nohtabinbank
    cmplw   r11, r15
    ble     @notlargestbank
    mr      r13, r12
    mr      r15, r11
@notlargestbank
    bdnz    @bankloop

; Not sure??
    subi    r12, r22, 1
    neg     r11, r13
    and     r12, r11, r12
    add     r13, r13, r12
    subf    r15, r12, r15
    clrrwi  r15, r15, 10

; Page Size is always 2^12 on 32-bit PowerPC
    li      r11, 0x1000
    stw     r11, KDP.ProcInfo.PageSize(r1)

; Calculate Cache Block Size using DCBZ
    li      r11, -1
    li      r10, 1024
@unzerobytes                    ; set a kilobyte to FFFF...
    subic.  r10, r10, 4
    stwx    r11, r21, r10
    bne     @unzerobytes
    dcbz    0, r21              ; zero the first cache block
@cntzerobytes
    addi    r10, r10,  0x01
    lbzx    r11, r21, r10
    cmpwi   r11,  0x00
    beq     @cntzerobytes       ; count the zero bytes
    sth     r10, KDP.ProcInfo.CoherencyBlockSize(r1)
    sth     r10, KDP.ProcInfo.ReservationGranuleSize(r1)
    sth     r10, KDP.ProcInfo.DataCacheBlockSizeTouch(r1)
    sth     r10, KDP.ProcInfo.InstCacheBlockSize(r1)
    sth     r10, KDP.ProcInfo.DataCacheBlockSize(r1)

; Prepare first copied code
    lis     r12, -0x8000
    add     r11, r21, r22
    addi    r11, r11, -0xe6e
    addis   r10, r21, 1
@mangle
    stwu    r11, -4(r10)
    rlwimi  r12, r10, 29, 29, 31
    stwu    r12, -4(r10)
    cmpw    r10, r21
    rlwinm  r9, r10,  9,  7, 19
    tlbie   r9
    bne     @mangle

; Calculate Data Cache Size
    lwz     r11, KDP.CodeBase(r1)   ; Put timer code in RAM
    li      r12, (TimeDataCacheEnd-TimeDataCache)/4
    mtctr   r12
    add     r20, r21, r22
    addi    r11, r11, TimeDataCacheEnd-CodeBase
@mangle2
    lwzu    r12, -4(r11)
    stwu    r12, -4(r20)
    dcbst   0, r20
    icbi    0, r20
    bdnz    @mangle2
    sync
    isync

    stw     r0, KDP.ProcInfo.DataCacheTotalSize(r1)

    li      r17, 0                  ; r17 cache size to trial
    li      r18, 512                ; these three are for the victim code
    li      r19, 0
    li      r16, -1
    b       @enterdcacheloop
@dcacheloop
    addi    r17, r17, 512
    cmplw   r17, r15
    bge     @gotcachesize
@enterdcacheloop
    mtlr    r20
    blrl                            ; call TimeDataCache!
    ble     @dcacheloop
    subi    r12, r17, 512
    stw     r12, KDP.ProcInfo.DataCacheTotalSize(r1)
@gotcachesize

; And onto something else
    li      r12, 1
    sth     r12, KDP.ProcInfo.DataCacheAssociativity(r1)

; Get Data Cache Associativity
    lwz     r18, KDP.ProcInfo.DataCacheTotalSize(r1)
    mr      r17, r18
    li      r19,  0x00
    li      r16, -0x01
    b       new_world_0x75c
new_world_0x750
    add     r17, r17, r18
    cmplw   r17, r15
    bge     new_world_0x774
new_world_0x75c
    mtlr    r20
    blrl
    ble     new_world_0x750
    subf    r17, r18, r17
    divwu   r12, r17, r18
    sth     r12, KDP.ProcInfo.DataCacheAssociativity(r1)
new_world_0x774

; Get Cache Line Size
    lwz     r17, KDP.ProcInfo.DataCacheTotalSize(r1)
    lhz     r18, KDP.ProcInfo.DataCacheAssociativity(r1)
    slwi    r17, r17,  1
    divwu   r18, r17, r18
    srwi    r19, r18,  1
    li      r14,  0x200
    add     r19, r19, r14
    li      r16, -0x01
    b       new_world_0x7ac
new_world_0x798
    lhz     r12, KDP.ProcInfo.DataCacheBlockSize(r1)
    cmplw   r14, r12
    ble     new_world_0x7bc
    srwi    r14, r14,  1
    subf    r19, r14, r19
new_world_0x7ac
    mtlr    r20
    blrl
    ble     new_world_0x798
    slwi    r12, r14,  1
new_world_0x7bc
    sth     r12, KDP.ProcInfo.DataCacheLineSize(r1)

; Get Data Cache Associativity
    mtsdr1  r21
    mr      r14, r13
    li      r13,  0xff0
    sth     r0, KDP.ProcInfo.TransCacheTotalSize(r1)
    li      r17,  0x00
    lwz     r18, KDP.ProcInfo.PageSize(r1)
    li      r19,  0x00
    li      r16, -0x01
    b       new_world_0x7f4
new_world_0x7e4
    add     r17, r17, r18
    lis     r12,  0x3f
    cmplw   r17, r12
    bge     new_world_0x82c
new_world_0x7f4
    mtlr    r20
    mfmsr   r12
    ori     r12, r12,  0x10
    mtmsr   r12
    isync
    blrl
    mfmsr   r12
    rlwinm  r12, r12,  0, 28, 26
    mtmsr   r12
    isync
    ble     new_world_0x7e4
    subf    r17, r18, r17
    divwu   r12, r17, r18
    sth     r12, KDP.ProcInfo.TransCacheTotalSize(r1)
new_world_0x82c
    li      r12,  0x01
    sth     r12, KDP.ProcInfo.TransCacheAssociativity(r1)
    li      r17,  0x00
    lis     r18,  0x40
    li      r19,  0x00
    li      r16, -0x01
    b       new_world_0x858

new_world_0x848
    add     r17, r17, r18
    lis     r12,  0x200
    cmplw   r17, r12
    bge     new_world_0x890

new_world_0x858
    mtlr    r20
    mfmsr   r12
    ori     r12, r12,  0x10
    mtmsr   r12
    isync
    blrl
    mfmsr   r12
    rlwinm  r12, r12,  0, 28, 26
    mtmsr   r12
    isync
    ble     new_world_0x848
    subf    r17, r18, r17
    divwu   r12, r17, r18
    sth     r12, KDP.ProcInfo.TransCacheAssociativity(r1)
new_world_0x890
    mr      r13, r14
    addi    r12, r22, -0x01
    srwi    r12, r12, 16
    or      r12, r12, r21
    mtsdr1  r12

########################################################################

; Assume that I-Cache shares topology with D-Cache
    lwz     r12, KDP.ProcInfo.DataCacheTotalSize(r1)
    stw     r12, KDP.ProcInfo.InstCacheTotalSize(r1)
    lhz     r12, KDP.ProcInfo.DataCacheAssociativity(r1)
    sth     r12, KDP.ProcInfo.InstCacheAssociativity(r1)
    lhz     r12, KDP.ProcInfo.DataCacheLineSize(r1)
    sth     r12, KDP.ProcInfo.InstCacheLineSize(r1)

; Determine whether I-Cache and D-Cache are mutually coherent
    lis     r11, 0x3960         ; li r11, 0 <- Place instructions in RAM
    stw     r11, 0(r21)
    lisori  r11, 0x4e800020     ; place a blr after to return here
    stw     r11, 4(r21)
    dcbst   0, r21              ; Flush D/I cache and run the code
    sync
    icbi    0, r21
    isync
    mtlr    r21
    blrl
    li      r11, 1
    sth     r11, 2(r21)         ; li r11, 1 <- Change operand of first inst
    sync
    isync
    mtlr    r21                 ; Run without flushing: combined if it works
    blrl
    sth     r11, KDP.ProcInfo.CombinedCaches(r1)

; Now do creepy stuff with the instruction caches
    cmpwi   r11, 1
    beq     CachesCombined

    lwz     r11, KDP.CodeBase(r1)
    li      r12, (TimeInstCacheEnd - TimeInstCache) / 4
    mtctr   r12
    add     r20, r21, r22
    addi    r11, r11, TimeInstCacheEnd - CodeBase

new_world_0x924
    lwzu    r12, -0x0004(r11)
    stwu    r12, -0x0004(r20)
    dcbst   0, r20
    icbi    0, r20
    bdnz    new_world_0x924
    sync
    isync
    subf    r12, r21, r20
    mulli   r12, r12,  0x80
    cmplw   r12, r15
    bge     new_world_0x958
    mr      r15, r12

new_world_0x958
    add     r12, r13, r15
    mr      r11, r20
    lis     r10,  0x4e80
    ori     r10, r10,  0x20

new_world_0x968
    lwzu    r9, -0x0200(r12)
    stw     r10,  0x0000(r12)
    cmpw    r12, r13
    stwu    r9, -0x0004(r11)
    dcbst   0, r12
    icbi    0, r12
    bne     new_world_0x968
    sync
    isync

    stw     r0, KDP.ProcInfo.InstCacheTotalSize(r1)
    li      r17,  0x00
    li      r18,  0x200
    li      r19,  0x00
    li      r16, -0x01
    b       new_world_0x9b4

new_world_0x9a8
    addi    r17, r17,  0x200
    cmplw   r17, r15
    bge     new_world_0x9c8

new_world_0x9b4
    mtlr    r20
    blrl
    ble     new_world_0x9a8
    addi    r12, r17, -0x200
    stw     r12, KDP.ProcInfo.InstCacheTotalSize(r1)

new_world_0x9c8
    li      r12,  0x01
    sth     r12, KDP.ProcInfo.InstCacheAssociativity(r1)
    lwz     r18, KDP.ProcInfo.InstCacheTotalSize(r1)
    mr      r17, r18
    li      r19,  0x00
    li      r16, -0x01
    b       new_world_0x9f0

new_world_0x9e4
    add     r17, r17, r18
    cmplw   r17, r15
    bge     new_world_0xa08

new_world_0x9f0
    mtlr    r20
    blrl
    ble     new_world_0x9e4
    subf    r17, r18, r17
    divwu   r12, r17, r18
    sth     r12, KDP.ProcInfo.InstCacheAssociativity(r1)

new_world_0xa08
    add     r12, r13, r15
    mr      r11, r20

new_world_0xa10
    lwzu    r9, -0x0004(r11)
    stwu    r9, -0x0200(r12)
    cmpw    r12, r13
    dcbst   0, r12
    icbi    0, r12
    bne     new_world_0xa10
    sync
    isync
    lwz     r17, KDP.ProcInfo.InstCacheTotalSize(r1)
    lhz     r18, KDP.ProcInfo.InstCacheAssociativity(r1)
    divwu   r18, r17, r18
    slwi    r17, r17,  1
    add     r12, r13, r17
    subi    r11, r21, 4

new_world_0xa4c
    subf    r12, r18, r12
    li      r14,  0x400

new_world_0xa54
    rlwinm. r14, r14, 31,  0, 28
    lwzx    r9, r12, r14
    lis     r10,  0x4e80
    ori     r10, r10,  0x20
    stwx    r10, r12, r14
    stwu    r9,  0x0004(r11)
    dcbst   r12, r14
    icbi    r12, r14
    addi    r14, r14,  0x04
    lwzx    r9, r12, r14
    lis     r10,  0x4bff
    ori     r10, r10,  0xfffc
    stwx    r10, r12, r14
    stwu    r9,  0x0004(r11)
    dcbst   r12, r14
    icbi    r12, r14
    bne     new_world_0xa54
    cmpw    r12, r13
    bne     new_world_0xa4c
    sync
    isync
    mr      r19, r18
    slwi    r18, r18,  1
    li      r14,  0x200
    add     r19, r19, r14
    li      r16, -0x01
    b       new_world_0xadc

new_world_0xac8
    li      r12,  0x08
    cmplw   r14, r12
    ble     new_world_0xaec
    srwi    r14, r14,  1
    subf    r19, r14, r19

new_world_0xadc
    mtlr    r20
    blrl
    ble     new_world_0xac8
    slwi    r12, r14,  1

new_world_0xaec
    sth     r12, KDP.ProcInfo.InstCacheLineSize(r1)
    srwi    r18, r18,  1
    add     r12, r13, r17
    subi    r11, r21, 4

new_world_0xafc
    subf    r12, r18, r12
    li      r14,  0x400

new_world_0xb04
    rlwinm. r14, r14, 31,  0, 28
    lwzu    r9,  0x0004(r11)
    stwx    r9, r12, r14
    addi    r14, r14,  0x04
    lwzu    r9,  0x0004(r11)
    stwx    r9, r12, r14
    bne     new_world_0xb04
    cmpw    r12, r13
    bne     new_world_0xafc

CachesCombined

########################################################################

    b       CalculatedProcessorInfo

TimeDataCache ; r18 = 512, r19 = 0, r16 = -1 // LE if our time improved by more than 1%
    li      r10, 3              ; r10 = master counter

@three
    li      r12, 0x800
    mtctr   r12
    add     r19, r19, r13       ; edits r19 but puts it back later
    li      r11, 0
    mtdec   r11
@delayloop
    subf    r12, r17, r11
    srawi   r12, r12, 31
    and     r11, r11, r12
    lbzx    r12, r13, r11
    add     r12, r12, r12
    lbzx    r12, r19, r11
    add     r12, r12, r12
    add     r11, r11, r18
    bdnz    @delayloop
    subf    r19, r13, r19
    mfdec   r12
    neg     r12, r12

    cmplw   r12, r16
    bgt     @notquickest
    mr      r16, r12
@notquickest

    srwi    r11, r12, 7         ; return LE if our time improved by more than 1%
    subf    r12, r11, r12
    cmpw    r12, r16
    blelr

    subic.  r10, r10, 1
    bgt     @three
    cmpw    r12, r16            ; else return GT
    blr

    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
TimeDataCacheEnd

TimeInstCache
    li      r10,  0x03
    mflr    r9
TimeInstCache_0x8
    li      r12,  0x800
    mtctr   r12
    add     r19, r19, r13
    li      r11,  0x00
    mtdec   r11
TimeInstCache_0x1c
    subf    r12, r17, r11
    srawi   r12, r12, 31
    and     r11, r11, r12
    add     r12, r13, r11
    mtlr    r12
    bclrl   20, cr3_lt      ; branch if (decremented-ctr == 0) AND (condition is true) ... obscure!
    add     r12, r19, r11
    mtlr    r12
    bclrl   20, cr3_lt
    add     r11, r11, r18
    bdnz    TimeInstCache_0x1c
    subf    r19, r13, r19
    mfdec   r12
    neg     r12, r12
    cmplw   r12, r16
    bgt     TimeInstCache_0x60
    mr      r16, r12
TimeInstCache_0x60
    srwi    r11, r12,  7
    subf    r12, r11, r12
    cmpw    r12, r16
    mtlr    r9
    blelr
    addic.  r10, r10, -0x01
    bgt     TimeInstCache_0x8
    cmpw    r12, r16
    blr
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
    isync
TimeInstCacheEnd

########################################################################

HID0SelectTable
    dc.l 0x0300031B
    dc.l 0x0A1B1B1B
    dc.l 0x030A0303
    dc.l 0x03030303
HID0EnableTable
    dc.l 0x01000102
    dc.l 0x01020202
    dc.l 0x01010101
    dc.l 0x01010101

########################################################################

ProcessorInfoTable
; 601
    dc.l    0x1000      ; PageSize
    dc.l    0x8000      ; DataCacheTotalSize
    dc.l    0x8000      ; InstCacheTotalSize
    dc.w    0x20        ; CoherencyBlockSize
    dc.w    0x20        ; ReservationGranuleSize
    dc.w    1           ; CombinedCaches
    dc.w    0x40        ; InstCacheLineSize
    dc.w    0x40        ; DataCacheLineSize
    dc.w    0x20        ; DataCacheBlockSizeTouch
    dc.w    0x20        ; InstCacheBlockSize
    dc.w    0x20        ; DataCacheBlockSize
    dc.w    8           ; InstCacheAssociativity
    dc.w    8           ; DataCacheAssociativity
    dc.w    0x100       ; TransCacheTotalSize
    dc.w    2           ; TransCacheAssociativity

; 603
    dc.l    0x1000      ; PageSize
    dc.l    0x2000      ; DataCacheTotalSize
    dc.l    0x2000      ; InstCacheTotalSize
    dc.w    0x20        ; CoherencyBlockSize
    dc.w    0x20        ; ReservationGranuleSize
    dc.w    0           ; CombinedCaches
    dc.w    0x20        ; InstCacheLineSize
    dc.w    0x20        ; DataCacheLineSize
    dc.w    0x20        ; DataCacheBlockSizeTouch
    dc.w    0x20        ; InstCacheBlockSize
    dc.w    0x20        ; DataCacheBlockSize
    dc.w    2           ; InstCacheAssociativity
    dc.w    2           ; DataCacheAssociativity
    dc.w    0x40        ; TransCacheTotalSize
    dc.w    2           ; TransCacheAssociativity

; 604
    dc.l    0x1000      ; PageSize
    dc.l    0x4000      ; DataCacheTotalSize
    dc.l    0x4000      ; InstCacheTotalSize
    dc.w    0x20        ; CoherencyBlockSize
    dc.w    0x20        ; ReservationGranuleSize
    dc.w    0           ; CombinedCaches
    dc.w    0x20        ; InstCacheLineSize
    dc.w    0x20        ; DataCacheLineSize
    dc.w    0x20        ; DataCacheBlockSizeTouch
    dc.w    0x20        ; InstCacheBlockSize
    dc.w    0x20        ; DataCacheBlockSize
    dc.w    4           ; InstCacheAssociativity
    dc.w    4           ; DataCacheAssociativity
    dc.w    0x80        ; TransCacheTotalSize
    dc.w    2           ; TransCacheAssociativity

; 603e
    dc.l    0x1000      ; PageSize
    dc.l    0x4000      ; DataCacheTotalSize
    dc.l    0x4000      ; InstCacheTotalSize
    dc.w    0x20        ; CoherencyBlockSize
    dc.w    0x20        ; ReservationGranuleSize
    dc.w    0           ; CombinedCaches
    dc.w    0x20        ; InstCacheLineSize
    dc.w    0x20        ; DataCacheLineSize
    dc.w    0x20        ; DataCacheBlockSizeTouch
    dc.w    0x20        ; InstCacheBlockSize
    dc.w    0x20        ; DataCacheBlockSize
    dc.w    4           ; InstCacheAssociativity
    dc.w    4           ; DataCacheAssociativity
    dc.w    0x40        ; TransCacheTotalSize
    dc.w    2           ; TransCacheAssociativity

; 750
    dc.l    0x1000      ; PageSize
    dc.l    0x4000      ; DataCacheTotalSize
    dc.l    0x4000      ; InstCacheTotalSize
    dc.w    0x20        ; CoherencyBlockSize
    dc.w    0x20        ; ReservationGranuleSize
    dc.w    0           ; CombinedCaches
    dc.w    0x20        ; InstCacheLineSize
    dc.w    0x20        ; DataCacheLineSize
    dc.w    0x20        ; DataCacheBlockSizeTouch
    dc.w    0x20        ; InstCacheBlockSize
    dc.w    0x20        ; DataCacheBlockSize
    dc.w    4           ; InstCacheAssociativity
    dc.w    4           ; DataCacheAssociativity
    dc.w    0x40        ; TransCacheTotalSize
    dc.w    2           ; TransCacheAssociativity

; 750FX
    dc.l    0x1000      ; PageSize
    dc.l    0x8000      ; DataCacheTotalSize
    dc.l    0x8000      ; InstCacheTotalSize
    dc.w    0x20        ; CoherencyBlockSize
    dc.w    0x20        ; ReservationGranuleSize
    dc.w    0           ; CombinedCaches
    dc.w    0x20        ; InstCacheLineSize
    dc.w    0x20        ; DataCacheLineSize
    dc.w    0x20        ; DataCacheBlockSizeTouch
    dc.w    0x20        ; InstCacheBlockSize
    dc.w    0x20        ; DataCacheBlockSize
    dc.w    8           ; InstCacheAssociativity
    dc.w    8           ; DataCacheAssociativity
    dc.w    0x80        ; TransCacheTotalSize
    dc.w    2           ; TransCacheAssociativity

; ???
    dc.l    0x1000      ; PageSize
    dc.l    0x8000      ; DataCacheTotalSize
    dc.l    0x8000      ; InstCacheTotalSize
    dc.w    0x20        ; CoherencyBlockSize
    dc.w    0x20        ; ReservationGranuleSize
    dc.w    0           ; CombinedCaches
    dc.w    0x20        ; InstCacheLineSize
    dc.w    0x20        ; DataCacheLineSize
    dc.w    0x20        ; DataCacheBlockSizeTouch
    dc.w    0x20        ; InstCacheBlockSize
    dc.w    0x20        ; DataCacheBlockSize
    dc.w    4           ; InstCacheAssociativity
    dc.w    4           ; DataCacheAssociativity
    dc.w    0x80        ; TransCacheTotalSize
    dc.w    2           ; TransCacheAssociativity

; ??? unused
    dc.l    0x1000      ; PageSize
    dc.l    0x8000      ; DataCacheTotalSize
    dc.l    0x8000      ; InstCacheTotalSize
    dc.w    0x20        ; CoherencyBlockSize
    dc.w    0x20        ; ReservationGranuleSize
    dc.w    1           ; CombinedCaches
    dc.w    0x20        ; InstCacheLineSize
    dc.w    0x20        ; DataCacheLineSize
    dc.w    0x20        ; DataCacheBlockSizeTouch
    dc.w    0x20        ; InstCacheBlockSize
    dc.w    0x20        ; DataCacheBlockSize
    dc.w    8           ; InstCacheAssociativity
    dc.w    8           ; DataCacheAssociativity
    dc.w    0x80        ; TransCacheTotalSize
    dc.w    4           ; TransCacheAssociativity

ChosenProcessorInfo
@loop
    subic.  r9, r9, 4
    lwzx    r12, r11, r9
    stwx    r12, r10, r9
    bgt     @loop
CalculatedProcessorInfo
