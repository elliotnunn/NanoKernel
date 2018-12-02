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

    lwz     r8, CB.CTR+4(r6)
    lwz     r25, CB.r25+4(r6)
    sync
    mtctr   r8
    blr
