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

    subi    r11, r11, NKProcessorInfo.OvrEnd - NKProcessorInfo.Ovr
    b       ChosenProcessorInfo

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
    dc.w    0x40        ; TransCacheTotalSize
    dc.w    2           ; TransCacheAssociativity

ChosenProcessorInfo
@loop
    subic.  r9, r9, 4
    lwzx    r12, r11, r9
    stwx    r12, r10, r9
    bgt     @loop
