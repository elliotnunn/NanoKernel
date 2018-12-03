FlushCaches
    mfctr   r8
    stw     r25, CB.r25+4(r6)               ; used for cache size
    stw     r8, CB.CTR+4(r6)

; L1
    lhz     r25, KDP.ProcInfo.DataCacheLineSize(r1)
    cntlzw  r8, r25
    subfic  r9, r8, 31                      ; r9 = logb(L1-D line size)
    lwz     r8, KDP.ProcInfo.DataCacheTotalSize(r1)
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
