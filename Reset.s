Reset
; Code that inits the NanoKernel after Init.s runs,
; or re-inits the NanoKernel after a 68k RESET trap

; These registers will be used throughout:
rCI     set     r26
        lwz     rCI, KDP.ConfigInfoPtr(r1)
rNK     set     r25
        lwz     rNK, KDP.CodeBase(r1)
rPgMap  set     r18
        lwz     rPgMap, KDP.PageMapPtr(r1)
rXER    set     r17
        mfxer   rXER

########################################################################

ResetVectorTables
; Userspace tables for System and Alternate contexts
    _kaddr  r23, rNK, Crash             ; crash on unknown interrupt
    addi    r8, r1, KDP.VecTblSystem
    li      r22, 3 * VecTbl.Size
@loop
    subic.  r22, r22, 4
    stwx    r23, r8, r22
    bne     @loop

rSys set r9     ; equates to help readability below
rAlt set r8
    addi    rSys, r1, KDP.VecTblSystem
    mtsprg  3, rSys
    addi    rAlt, r1, KDP.VecTblAlternate

    _kaddr  r23, rNK, Crash
    stw     r23, VecTbl.SystemReset(rSys)
    stw     r23, VecTbl.SystemReset(rAlt)

    _kaddr  r23, rNK, MachineCheckInt
    stw     r23, VecTbl.MachineCheck(rSys)
    stw     r23, VecTbl.MachineCheck(rAlt)

    _kaddr  r23, rNK, DataStorageInt
    stw     r23, VecTbl.DataStorage(rSys)
    stw     r23, VecTbl.DataStorage(rAlt)

    _kaddr  r23, rNK, InstStorageInt
    stw     r23, VecTbl.InstStorage(rSys)
    stw     r23, VecTbl.InstStorage(rAlt)

    lwz     r23, KDP.IntHandlerPtr(r1)
    stw     r23, VecTbl.External(rSys)

    _kaddr  r23, rNK, ProgramInt
    stw     r23, VecTbl.External(rAlt)

    _kaddr  r23, rNK, AlignmentInt
    stw     r23, VecTbl.Alignment(rSys)
    stw     r23, VecTbl.Alignment(rAlt)

    _kaddr  r23, rNK, ProgramInt
    stw     r23, VecTbl.Program(rSys)
    stw     r23, VecTbl.Program(rAlt)

    _kaddr  r23, rNK, FPUnavailInt
    stw     r23, VecTbl.FPUnavail(rSys)
    stw     r23, VecTbl.FPUnavail(rAlt)

    _kaddr  r23, rNK, DecrementerIntSys
    stw     r23, VecTbl.Decrementer(rSys)
    _kaddr  r23, rNK, DecrementerIntAlt
    stw     r23, VecTbl.Decrementer(rAlt)

    _kaddr  r23, rNK, SysCallInt
    stw     r23, VecTbl.SysCall(rSys)
    stw     r23, VecTbl.SysCall(rAlt)

    _kaddr  r23, rNK, TraceInt
    stw     r23, VecTbl.Trace(rSys)
    stw     r23, VecTbl.Trace(rAlt)
    stw     r23, 0x80(rSys) ; unknown way to force a trace exception
    stw     r23, 0x80(rAlt)

; MemRetry vector table
    addi    r8, r1, KDP.VecTblMemRetry

    _kaddr  r23, rNK, MRMachineCheckInt
    stw     r23, VecTbl.MachineCheck(r8)

    _kaddr  r23, rNK, MRDataStorageInt
    stw     r23, VecTbl.DataStorage(r8)

########################################################################

ResetKCallTable
; The dispatch table for PowerPC traps
    _kaddr  r23, rNK, KCallSystemCrash      ; Crash on unknown calls
    addi    r8, r1, KDP.KCallTbl
    li      r22, KCallTbl.Size
@loop
    subic.  r22, r22, 4
    stwx    r23, r8, r22
    bne     @loop

    _kaddr  r23, rNK, KCallReturnFromException
    stw     r23, KCallTbl.ReturnFromException(r8)

    _kaddr  r23, rNK, KCallRunAlternateContext
    stw     r23, KCallTbl.RunAlternateContext(r8)

    _kaddr  r23, rNK, KCallResetSystem
    stw     r23, KCallTbl.ResetSystem(r8)

    _kaddr  r23, rNK, KCallVMDispatch
    stw     r23, KCallTbl.VMDispatch(r8)

    _kaddr  r23, rNK, KCallPrioritizeInterrupts
    stw     r23, KCallTbl.PrioritizeInterrupts(r8)

    _kaddr  r23, rNK, KCallSystemCrash
    stw     r23, KCallTbl.SystemCrash(r8)

########################################################################

ResetNCBPointerCache
    _clrNCBCache scr=r23

########################################################################

ResetHTAB
; Put HTABORG and PTEGMask in KDP, and zero out the last PTEG
    mfspr   r8, sdr1

    rlwinm  r22, r8, 16, 7, 15      ; Get settable HTABMASK bits
    rlwinm  r8, r8, 0, 0, 15        ; and HTABORG

    ori     r22, r22, (-64) & 0xffff; "PTEGMask" from upper half of HTABMASK

    stw     r8, KDP.HTABORG(r1)     ; Save
    stw     r22, KDP.PTEGMask(r1)

    li      r23, 0                  ; Zero out the last PTEG in the HTAB
    addi    r22, r22, 64
@nextsegment
    subic.  r22, r22, 4
    stwx    r23, r8, r22
    bgt     @nextsegment
@skip_zeroing_pteg

    bl      FlushTLB                ; Flush the TLB after touching the HTAB

########################################################################

ResetPageMap
; unstructured buffer of 8-byte "PMDTs"
    lwz     r9, NKConfigurationInfo.PageMapInitOffset(rCI)
    lwz     r22, NKConfigurationInfo.PageMapInitSize(rCI)
    add     r9, r9, rCI
@nextpmdt
    subi    r22, r22, 4
    lwzx    r21, r9, r22                ; Get RealPgNum/Flags word
    andi.   r23, r21, Pattr_NotPTE | Pattr_PTE_Rel
    cmpwi   r23, Pattr_PTE_Rel          ; Change if physical
    bne     @nonrelative                ; address is relative.
    rlwinm  r21, r21, 0, ~Pattr_PTE_Rel
    add     r21, r21, rCI
@nonrelative
    stwx    r21, rPgMap, r22            ; ...save
    subic.  r22, r22, 4                 ; Get Logical/Len word
    lwzx    r20, r9, r22
    stwx    r20, rPgMap, r22            ; ...save
    bgt     @nextpmdt

SetSpecialPMDTs
; The NanoKernel sets the physical addresses of these special PMDTs
    lwz     r8, NKConfigurationInfo.PageMapIRPOffset(rCI)
    add     r8, rPgMap, r8
    lwz     r23, PMDT.Word2(r8)
    rlwimi  r23, r1, 0, 0xFFFFF000
    stw     r23, PMDT.Word2(r8)

    lwz     r8, NKConfigurationInfo.PageMapKDPOffset(rCI)
    add     r8, rPgMap, r8
    lwz     r23, PMDT.Word2(r8)
    rlwimi  r23, r1, 0, 0xFFFFF000
    stw     r23, PMDT.Word2(r8)

    lwz     r19, KDP.EDPPtr(r1)
    lwz     r8, NKConfigurationInfo.PageMapEDPOffset(rCI)
    add     r8, rPgMap, r8
    lwz     r23, PMDT.Word2(r8)
    rlwimi  r23, r19, 0, 0xFFFFF000
    stw     r23, PMDT.Word2(r8)

ResetSegMaps
; four structured 16-element arrays of pointers into the PageMap
    addi    r9, rCI, NKConfigurationInfo.SegMaps-4
    addi    r8, r1, KDP.SegMaps-4
    li      r22, 4*16*8                 ; 4 maps * 16 segs * (ptr+flags=8b)
@nextseg
    lwzu    r23, 4(r9)
    subic.  r22, r22, 8
    add     r23, rPgMap, r23
    stwu    r23, 4(r8)
    lwzu    r23, 4(r9)
    stwu    r23, 4(r8)
    bgt     @nextseg

ResetBatRanges
; 16 U/L-BATs, indexed by 4-bit nybbles in a 32-bit BatMap word
    addi    r9, rCI, NKConfigurationInfo.BATRangeInit - 4
    addi    r8, r1, KDP.BatRanges - 4
    li      r22, 4*4*8                  ; 4 maps * 4 BATs * (UBAT+LBAT=8b)
@nextbatrange
    lwzu    r20, 4(r9)                  ; load upper
    lwzu    r21, 4(r9)                  ; load lower
    stwu    r20, 4(r8)                  ; store upper
    rlwinm  r23, r21, 0, ~Pattr_PTE_Rel
    cmpw    r21, r23
    beq     @nonrelative
    add     r21, r23, rCI
@nonrelative
    subic.  r22, r22, 8
    stwu    r21, 4(r8)                  ; store lower
    bgt     @nextbatrange

########################################################################

ResetAddressSpaceRecords
; SetSpace takes a pointer to one of these records
    addi    r23, r1, KDP.SupervisorSegMap
    stw     r23, KDP.SupervisorSpace.SegMapPtr(r1)
    lwz     r23, NKConfigurationInfo.BatMap32SupInit(rCI)
    stw     r23, KDP.SupervisorSpace.BatMap(r1)

    addi    r23, r1, KDP.UserSegMap
    stw     r23, KDP.UserSpace.SegMapPtr(r1)
    lwz     r23, NKConfigurationInfo.BatMap32UsrInit(rCI)
    stw     r23, KDP.UserSpace.BatMap(r1)

    addi    r23, r1, KDP.CpuSegMap
    stw     r23, KDP.CpuSpace.SegMapPtr(r1)
    lwz     r23, NKConfigurationInfo.BatMap32CPUInit(rCI)
    stw     r23, KDP.CpuSpace.BatMap(r1)

    addi    r23, r1, KDP.OverlaySegMap
    stw     r23, KDP.OverlaySpace.SegMapPtr(r1)
    lwz     r23, NKConfigurationInfo.BatMap32OvlInit(rCI)
    stw     r23, KDP.OverlaySpace.BatMap(r1)

########################################################################

GetMaxVirtualPagesFromPageMap
    li      r22, 0
    addi    r19, r1, KDP.SegMaps - 8
@nextseg
    lwzu    r8, 8(r19)          ; get ptr to first PMDT of next segment
    lwz     r30, 0(r8)          ; PMDT.PageIdx/PMDT.PageCount
    lwz     r31, 4(r8)          ; PMDT.Word2 (for testing flags)

    cmplwi  cr7, r30, 0xffff
    rlwinm. r31, r31, 0, PMDT_Paged
    bgt     cr7, @done          ; if PMDT.PageIdx > 0, stop counting
    beq     @done               ; if not PMDT_Paged, stop counting (odd check!)

    add     r22, r22, r30
    addi    r22, r22, 1         ; add one more page because PMDT.PageCount is 0-based
    beq     cr7, @nextseg       ; if PMDT.PageCount < 256 MB, this is last segment
@done
    stw     r22, KDP.VMMaxVirtualPages(r1)

########################################################################

Reset68kPageDescriptors
; Create a 68k PTE for every page in the initial logical area.
; (The logical area will equal physical RAM size, so make a PTE for
; every physical page inside a RAM bank but outside kernel memory.
; Later on, the VM Manager can replace this table with its own.)
    lwz     r21, KDP.KernelMemoryBase(r1)   ; this range is forbidden
    lwz     r20, KDP.KernelMemoryEnd(r1)
    subi    r29, r21, 4                     ; ptr to last added entry

    addi    r19, r1, KDP.SysInfo.Bank0Start - 8

    lwz     r23, KDP.PageAttributeInit(r1)  ; "default WIMG/PP settings for PTE creation"

    li      r30, M68pdResident
    _mvbit  r30, bM68pdCacheinhib, r23, bLpteInhibcache
    _mvbit  r30, bM68pdCacheNotIO, r23, bLpteWritethru
    xori    r30, r30, M68pdCacheNotIO
    _mvbit  r30, bM68pdModified, r23, bLpteChange
    _mvbit  r30, bM68pdUsed, r23, bLpteReference

    li      r23, NKSystemInfo.MaxBanks
@nextbank
    subic.  r23, r23, 1
    blt     @done
    lwzu    r31, 8(r19)                     ; bank start address
    lwz     r22, 4(r19)                     ; bank size
    or      r31, r31, r30                   ; OR the RPN with the flags in r30
@nextpage
    cmplwi  r22, 4096
    cmplw   cr6, r31, r21
    cmplw   cr7, r31, r20
    subi    r22, r22, 4096
    blt     @nextbank

    blt     cr6, @notkernelmem              ; check that page is not kernel memory
    blt     cr7, @kernelmem
@notkernelmem
    stwu    r31, 4(r29)                     ; write the PageList entry
@kernelmem

    addi    r31, r31, 4096
    b       @nextpage
@done

; (Now r21/r29 point to first/last element of PageList)

PlacePagedArea
; Overwrite the dummy (first) PMDT in every logical-area segment (0-3)
; to point into the logical-area 68k PTE array
    lwz     r8, KDP.VMMaxVirtualPages(r1)       ; Limit size of logical area!
    subf    r22, r21, r29
    slwi    r8, r8, 2
    cmplw   r22, r8
    blt     @useallpages
    subi    r22, r8, 4
@useallpages
    li      r30, 0
    addi    r19, r22, 4
    slwi    r19, r19, 10
    ori     r30, r30, 0xffff
    stw     r19, KDP.SysInfo.UsableMemorySize(r1)
    srwi    r22, r22, 2
    stw     r19, KDP.SysInfo.LogicalMemorySize(r1)
    srwi    r19, r19, 12
    stw     r19, KDP.VMLogicalPages(r1)
    stw     r19, KDP.VMPhysicalPages(r1)

    addi    r29, r1, KDP.PhysicalPageArray-4    ; where to save per-segment 68k-PD ptr
    addi    r19, r1, KDP.SupervisorSegMap-8     ; which part of PageMap to update 
    stw     r21, KDP.VMPageArray(r1)            ; note this vs 4 PhysicalPageArray ptrs
@nextsegment
    cmplwi  r22, 0xffff             ; 64k pages per segment
    
    lwzu    r8, 8(r19)              ; rewrite first PMDT in this segment:
    rotlwi  r31, r21, 10
    ori     r31, r31, PMDT_Paged
    stw     r30, 0(r8)              ; - to use entire segment (PageIdx = 0, PageCount = 0xFFFF)
    stw     r31, 4(r8)              ; - RPN = 68k-PD ptr | PMDT_NotPTE_PageList

    stwu    r21, 4(r29)             ; point nth seg's PhysicalPageArray ptr to seg's first 68k-PD
    addis   r21, r21, 4             ; increment pointer into 68k-PD (64k pages/segment * 4b/68k-PD)

    subis   r22, r22, 1
    bgt     @nextsegment
    sth     r22, PMDT.PageCount(r8) ; shrink PMDT in last segment to fit

########################################################################

ResetAddressSpace
    addi    r29, r1, KDP.OverlaySpace
    bl      SetSpace

########################################################################

PrimeHTAB
    lwz     r27, KDP.ConfigInfoPtr(r1)
    lwz     r27, NKConfigurationInfo.LA_InterruptCtl(r27)
    bl      PutPTE

    lwz     r27, KDP.ConfigInfoPtr(r1)
    lwz     r27, NKConfigurationInfo.LA_KernelData(r27)
    bl      PutPTE

    lwz     r27, KDP.ConfigInfoPtr(r1)
    lwz     r27, NKConfigurationInfo.LA_EmulatorData(r27)
    bl      PutPTE

########################################################################

; Restore the fixedpt exception register (clobbered by addic)
    mtxer   rXER

########################################################################

    lmw     r14, KDP.r14(r1)
    b       KCallPrioritizeInterrupts
