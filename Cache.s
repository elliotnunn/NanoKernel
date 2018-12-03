; Enable/disable/probe the L1/2 data/inst cache

; ARGUMENT (r3)
;   r3.hi = action flags
;     enable specified caches     $8000
;     disable specified caches    $4000
;     report pre-change state     $2000
;     also enable (???)           $1000
;     enable/disable I-cache      $0800
;     enable/disable D-cache      $0400
;
;   r3.lo = which cache (L1/L2)
;     level 1                     1
;     level 2                     2
;
; RETURN VALUE (r3)
;   r3.hi = pre-change state flags (resemble action flags)
;     both caches disabled        $4000
;     either cache enabled        $8000
;     I-cache enabled             $0800
;     D-cache enabled             $0400
;
;   r3.lo = return status
;     success                     0
;     failure                     < 0
;     checked L1 but did not set  1
;     checked L2 but did not set  2

KCallCacheDispatch
    stw     r21, CB.r21+4(r6)
    stw     r22, CB.r22+4(r6)
    stw     r23, CB.r23+4(r6)

    clrlwi  r8, r3, 16                          ; bad selector
    cmplwi  r8, 2
    bgt     cacheBadSelector

    lwz     r8, KDP.ProcInfo.ProcessorFlags(r1)
    andi.   r8, r8, 1 << NKProcessorInfo.hasL2CR
    beq     cacheFailAbsentL2CR                 ; no L2CR => fail (what about 601?)

    rlwinm. r9, r3, 0, 0x20000000               ; if flagged, get cache state in r23
    bnel    cacheGetInfo                        ; (otherwise, r23 is undefined)

    srwi    r8, r3, 30                          ; cannot enable *and* disable
    cmpwi   r8, 3
    beq     cacheBadFlags

    clrlwi  r8, r3, 16                          ; go to main code for level 1/2 cache
    cmplwi  r8, 1
    beq     cacheDispatchL1
    cmplwi  r8, 2
    beq     cacheDispatchL2

cacheBadSelector                                ; fall through => bad selector
    lisori  r3, -2
    b       cacheRet

########################################################################
; LEVEL 1 CACHE DISPATCH
cacheDispatchL1
    rlwinm. r9, r3, 0, 0x40000000
    bne     cacheDisableL1

    rlwinm. r9, r3, 0, 0x80000000
    bne     cacheEnableL1

    rlwinm. r9, r3, 0, 0x10000000               ; ???
    bl      FlushCaches
    b       cacheRet

cacheDisableL1
    bl      FlushCaches

    rlwinm  r22, r3, 0, 0x0C000000              ; shift arg bits to align with HID0[DCE/ICE]
    srwi    r22, r22, 12
    mfspr   r21, hid0
    andc    r21, r21, r22                       ; HID0 &= ~mybits
    sync
    mtspr   hid0, r21

    li      r3, 0
    b       cacheRet

cacheEnableL1
    rlwinm  r22, r3, 0, 0x0C000000              ; shift arg bits to align with HID0[DCE/ICE]
    srwi    r22, r22, 12
    mfspr   r21, hid0
    or      r21, r21, r22                       ; HID0 |= mybits
    sync
    mtspr   hid0, r21

    li      r3, 0
    b       cacheRet

########################################################################
; LEVEL 2 CACHE DISPATCH
cacheDispatchL2
    rlwinm. r9, r3, 0, 0x40000000
    bne     cacheDisableL2

    rlwinm. r9, r3, 0, 0x80000000
    bne     cacheEnableL2

    rlwinm. r9, r3, 0, 0x10000000
    bne     CacheCallL2Flag3                    ; goes to DisableSelected

    rlwinm. r9, r3, 0, 0x20000000
    bne     cacheRet

cacheBadFlags
    lisori  r3, -4
    b       cacheRet

CacheCallL2Flag3
    bl      cacheDisableL2                      ; typo? should be `b`

cacheEnableL2
    mfspr   r21, l2cr                           ; fail if L2CR[L2E] already set
    sync
    andis.  r21, r21, 0x8000
    bne     cacheRet

    lwz     r8, KDP.ProcInfo.ProcessorL2DSize(r1)
    and.    r8, r8, r8
    beq     cacheFailAbsentL2CR                 ; fail if zero-sized cache reported

    mfspr   r21, hid0                           ; save HID0

    rlwinm  r8, r21, 0, ~0x00100000             ; clear HID0[DPM] (dynamic power management)
    mtspr   hid0, r8                            ; presumably to keep L2 working while we wait?
    sync

    lwz     r8, KDP.ProcState.saveL2CR(r1)
    and.    r8, r8, r8
    beq     cacheRet                            ; fail if zero L2CR was saved?
    sync

    lis     r9, 0x0020                          ; set L2CR[GI] (global invalidate)
    or      r8, r8, r9
    mtspr   l2cr, r8
    sync
@inval_loop
    mfspr   r8, l2cr                            ; check L2CR[IP] (invalidate progress)
    sync
    andi.   r9, r8, 1
    bne     @inval_loop

    lis     r9, 0x0020                          ; clear L2CR[GI]
    andc    r8, r8, r9
    mtspr   l2cr, r8
    sync

    lis     r9, 0x8000                          ; set L2CR[L2E] (L2 enable)
    or      r8, r8, r9
    mtspr   l2cr, r8
    sync

    mtspr   hid0, r21                           ; restore HID0
    sync

    li      r3, 0                               ; return successfully
    b       cacheRet

cacheFailAbsentL2CR
    li      r3, -2
    b       cacheRet

cacheDisableL2
    mfspr   r22, l2cr                           ; return if already disabled per L2CR[L2E]
    sync
    andis.  r22, r22, 0x8000
    beq     cacheRet

    bl      FlushCaches

    mfspr   r22, l2cr                           ; clear L2CR[L2E]
    sync
    clrlwi  r22, r22, 1
    mtspr   l2cr, r22
    sync

    stw     r22, KDP.ProcState.saveL2CR(r1)  ; update saveL2CR
    sync

    rlwinm  r22, r22, 0, ~0x0E000000            ; clear L2CR[4/5/6] (all reserved)
    oris    r22, r22, 0x0010                    ; set L2CR[13] (also reserved)
    mtspr   l2cr, r22
    sync

########################################################################
; RETURN PATHS
cacheRet
    ori     r23, r23, 0xffff        ; put the r23.hi from cacheGetInfo into r3.hi
    oris    r3, r3, 0xffff
    and     r3, r3, r23
cacheRetWithoutFlags
    lwz     r21, CB.r21+4(r6)
    lwz     r22, CB.r22+4(r6)
    lwz     r23, CB.r23+4(r6)
    sync
    b       ReturnFromInt

########################################################################
; PROBE CODE
cacheGetInfo ; returns r23.hi = flags describing state of cache

    clrlwi  r8, r3, 16

    cmplwi  r8, 1
    beq     @level1
    cmplwi  r8, 2
    beq     @level2

    lisori  r3, -5
    b       cacheRetWithoutFlags

@level1
    mfspr   r21, hid0
    rlwinm. r21, r21, 12, 4, 5
    beq     @all_off

    oris    r23, r21, 0x8000
    blr

@level2
    lwz     r8, KDP.ProcInfo.ProcessorL2DSize(r1)
    and.    r8, r8, r8
    beq     cacheFailAbsentL2CR

    mfspr   r21, hid0               ; same bits as above
    rlwinm  r21, r21, 12, 4, 5

    mfspr   r22, l2cr               ; L2-D is on if L1-D is on and L2CR[DO] is cleared
    _mvbit0 r22, 4, r22, 9
    andc    r21, r21, r22

    mfspr   r22, l2cr               ; then again, both L2s are off if L2CR[L2E] is cleared
    andis.  r22, r22, 0x8000
    beq     @all_off

    or      r23, r21, r22
    blr

@all_off
    lisori  r23, 0x40000000
    blr

########################################################################

FlushCaches
    mfctr   r8
    stw     r25, CB.r25+4(r6)               ; used for cache size
    stw     r24, CB.r24+4(r6)
    stw     r8, CB.CTR+4(r6)

; L1
    lhz     r25, KDP.ProcInfo.DataCacheLineSize(r1)
    cntlzw  r8, r25
    subfic  r9, r8, 31                      ; r9 = logb(L1-D line size)
    lwz     r8, KDP.ProcInfo.DataCacheTotalSize(r1)

    lwz     r24, KDP.ProcInfo.ProcessorFlags(r1)
    andi.   r24, r24, 1 << NKProcessorInfo.hasPLRUL1
    beq     @noplru
    slwi    r24, r8, 1
    add     r8, r8, r24
    srwi    r8, r8, 1                       ; be generous with pseudo-LRU caches
@noplru

    srw     r8, r8, r9                      ; loop ctr = cache/line
    mtctr   r8
    lwz     r8, KDP.CodeBase(r1)            ; loop base = address in ROM
@loop
    lwzux   r9, r8, r25                     ; loop increment = L1 line size
    bdnz    @loop

; L2
    lwz     r24, KDP.ProcInfo.ProcessorFlags(r1)
    andi.   r24, r24, 1 << NKProcessorInfo.hasL2CR
    beq     @return                         ; return if L2CR unavailable

    mfspr   r24, l2cr
    andis.  r24, r24, 0x8000
    beq     @return                         ; return if L2 off (per L2CR[L2E])

    lhz     r25, KDP.ProcInfo.ProcessorL2DBlockSize(r1)
    cntlzw  r8, r25
    subfic  r9, r8, 31                      ; r9 = logb(L2-D line size)
    lwz     r8, KDP.ProcInfo.ProcessorL2DSize(r1)
    srw     r8, r8, r9
    mtctr   r8                              ; loop counter = cache/line

    mfspr   r24, l2cr                       ; set L2CR[DO] (disables L2-I)
    oris    r24, r24, 0x0040
    mtspr   l2cr, r24
    isync

    lwz     r8, KDP.CodeBase(r1)            ; loop base = address in ROM
    addis   r8, r8, 0x0010                  ; (start high and iterate down)
    subis   r8, r8, 1                       ; (lower due to my 310000 offset)
    neg     r25, r25                        ; loop increment = -(L2 line size)
@loop2
    lwzux   r9, r8, r25
    bdnz    @loop2

    rlwinm  r24, r24, 0, ~0x00400000        ; clear L2CR[DO] (reenables L2-I)
    mtspr   l2cr, r24
    isync

@return
    lwz     r8, CB.CTR+4(r6)
    lwz     r25, CB.r25+4(r6)
    lwz     r24, CB.r24+4(r6)
    sync
    mtctr   r8
    blr
