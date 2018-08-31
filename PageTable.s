; Code to populate the PowerPC "HTAB"/"Hash Table"

########################################################################

PutPTE ; EA r27 // PTE r30/r31, EQ=Success, GT=Invalid, LT=Fault
; 1. Find which Segment and PMDT cover this Effective Address
    lwz     r29, KDP.CurSpace.SegMapPtr(r1)
    rlwinm  r28, r27, 7, 0x0000000F << 3    ; get offset into SegMap based on EA
    lwzx    r29, r29, r28                   ; r29 is now our iterating PMDT ptr
    rlwinm  r28, r27, 20, 0x0000FFFF        ; r27 = page index within Segment
    lhz     r30, 0(r29)                     ; get first PMDT.PageIdx
    b       @find_pmdt
@next_pmdt
    lhzu    r30, 8(r29)                     ; get next PMDT.PageIdx
@find_pmdt
    lhz     r31, PMDT.PageCount(r29)
    subf    r30, r30, r28
    cmplw   cr7, r30, r31
    bgt     cr7, @next_pmdt                 ; Save "found PMDT pointer" in r29, "page index within PMDT" in r30

; 2. Parse the PMDT into a PTE (three major code paths)
    lwz     r28, KDP.HtabSinglePTE(r1)
    lwz     r31, PMDT.Word2(r29)
    cmpwi   cr7, r28, 0                     ; always delete the previous PMDT_PTE_Single entry from the HTAB
    extlwi. r26, r31, 2, 20                 ; use the Cond Reg to branch on Pattr_NotPTE/Pattr_PTE_Single
    bne     cr7, @del_single_pte
    blt     @paged                          ; PMDT_Paged is the probable meaning of Pattr_NotPTE (will return to @parsed_pmdt)
@did_del_single_pte                         ; (optimized return: if LT then @del_single_pte falls thru to @paged)
    bgt     @single_pte                     ; PMDT_PTE_Single is the probable meaning of Pattr_PTE_Single (will return to @parsed_pmdt)
    slwi    r28, r30, 12                    ; PMDT_PTE_Range is likely otherwise, requiring us to add an offset to the PMDT
    add     r31, r31, r28
@parsed_pmdt                                ; r31 = proposed new lower PTE, r26 = 
                                            ;   0 (if PMDT_PTE_Range)
                                            ;   0x5A5A (if PMDT_PTE_Single)
                                            ;   68k-PD pointer (if PMDT_Paged)

; 3. Find free slot in HTAB for new entry
    mfsrin  r30, r27
    rlwinm  r28, r27, 26, 10, 25            ; r28 = (1st arg of XOR) * 64b
    rlwinm  r30, r30, 6, 7, 25              ; r30 = (2nd arg of XOR) * 64b
    xor     r28, r28, r30                   ; r28 = (hash output) * 64b = r28 ^ r30
    lwz     r30, KDP.PTEGMask(r1)
    lwz     r29, KDP.HTABORG(r1)
    and     r28, r28, r30
    or.     r29, r29, r28                   ; r29 = PTEG pointer (clear CR0.EQ here so that @pteg_full knows we are trying primary hash)

@try_secondary_pteg                         ; @pteg_full jumps here to try sec'dary hash
    lwz     r30, 0(r29)                     ; Find "invalid" (bit 0 clear) PTE (optimized!)
    lwz     r28, 8(r29)
    cmpwi   cr6, r30, 0
    lwz     r30, 16(r29)
    cmpwi   cr7, r28, 0
    lwzu    r28, 24(r29)
    bge     cr6, @found_free_pte
    cmpwi   cr6, r30, 0
    lwzu    r30, 8(r29)
    bge     cr7, @found_free_pte
    cmpwi   cr7, r28, 0
    lwzu    r28, 8(r29)
    bge     cr6, @found_free_pte
    cmpwi   cr6, r30, 0
    lwzu    r30, 8(r29)
    bge     cr7, @found_free_pte
    cmpwi   cr7, r28, 0
    lwzu    r28, 8(r29)
    bge     cr6, @found_free_pte
    cmpwi   cr6, r30, 0
    addi    r29, r29, 8
    bge     cr7, @found_free_pte
    cmpwi   cr7, r28, 0
    addi    r29, r29, 8
    bge     cr6, @found_free_pte
    rlwinm  r28, r31, 0, LpteInhibcache     ; not sure why I bit in last entry dictates hash behaviour
    addi    r29, r29, 8
    blt     cr7, @pteg_full                 ; @pteg_full *may* return to @try_secondary_pteg
@found_free_pte                             ; Save PTE ptr + 24 in r29

; 4. Save the new PTE and return
    cmpwi   r26, 0                          
    mfsrin  r28, r27
    extrwi  r30, r27, 6, 4                  ; PTE[26-31=API] = high 6 bits of offset-within-segment
    stw     r27, KDP.HtabLastEA(r1)
    ori     r31, r31, LpteReference         ; set PTE[R]
    _mvbit  r30, bUpteHash, r31, 20         ; @pteg_full sets bit 20 of lower PTE to indicate which hash
    rlwinm  r31, r31, 0, ~Pattr_NotPTE      ; make sure this reserved bit is not carried over from PMDT
    insrwi  r30, r28, 24, 1                 ; get PTE[VSID] from segment register
    stw     r31, -20(r29)                   ; PTE[lo] = r31
    _ori    r30, r30, UpteValid             ; set PTE[V]
    sync                                    ; because we just wanged the page table
    stwu    r30, -24(r29)                   ; PTE[hi] = r30

    lwz     r28, KDP.NKInfo.HashTableCreateCount(r1)
    stw     r29, KDP.HtabLastPTE(r1)
    addi    r28, r28, 1
    stw     r28, KDP.NKInfo.HashTableCreateCount(r1)

    beqlr                                   ; PMDT_PTE_Range: return success (EQ)

    cmpwi   r26, 0x5A5A
    bne     @ret_notsingle                  ; PMDT_PTE_Single:
    stw     r29, KDP.HtabSinglePTE(r1)      ; save ptr to this ephemeral PTE
    cmpw    r29, r29                        ; return success (EQ)
    blr
@ret_notsingle

    lwz     r28, 0(r26)                     ; PMDT_Paged: Point 68k Page Descriptor
    lwz     r30, KDP.HTABORG(r1)            ; towards new PowerPC Page Table Entry
    ori     r28, r28, M68pdInHTAB | M68pdResident
    subf    r30, r30, r29
    cmpw    r29, r29
    rlwimi  r28, r30, 9, 0xFFFFF000
    stw     r28, 0(r26)
    blr                                     ; return success (EQ)

@del_single_pte ; Delete the PTE most recently created from a PMDT_PTE_Single entry.
    lwz     r28, KDP.NKInfo.HashTableDeleteCount(r1)
    lwz     r29, KDP.HtabSinglePTE(r1)
    addi    r28, r28, 1
    stw     r28, KDP.NKInfo.HashTableDeleteCount(r1)
    li      r28, 0
    stw     r28, 0(r29)
    lwz     r29, KDP.HtabSingleEA(r1)
    stw     r28, KDP.HtabSingleEA(r1)
    stw     r28, KDP.HtabSinglePTE(r1)
    sync
    tlbie   r29
    sync
    bge     @did_del_single_pte            ; Optimization: would otherwise branch to a "blt @paged"

@paged ; Probably PMDT_Paged: so find the 68k Page Descriptor and extract its info
; r30 = page index within area, r31 = RPN
    extlwi. r28, r31, 2, 21                 ; Put remaining two flags into top bits and set Cond Reg
    bge     @not_actually_paged             ; Not PMDT_Paged! (e.g. PMDT_InvalidAddress/PMDT_Available)

    rlwinm  r28, r30, 2, 0xFFFFFFFC         ; page index in segment * 4
    rlwinm  r26, r31, 22, 0xFFFFFFFC        ; ptr to first 68k-PD belonging to this segment
    lwzux   r28, r26, r28                   ; r26 = 68k-PD ptr, r28 = 68k-PD itself

    lwz     r31, KDP.PageAttributeInit(r1)
    andi.   r30, r28, M68pdInHTAB | M68pdSupProtect | M68pdResident
    rlwimi  r31, r28, 0, 0xFFFFF000
    cmplwi  r30, M68pdResident
    cmplwi  cr7, r30, M68pdSupProtect | M68pdResident

    ori     r31, r31, LpteReference
    _mvbit  r31, bLpteChange, r28, bM68pdModified
    _mvbit  r31, bLpteInhibcache, r28, bM68pdCacheinhib
    _mvbit  r31, bLpteWritethru, r28, bM68pdCacheNotIO
    xori    r31, r31, LpteWritethru
    _mvbit  r31, bLpteP1, r28, bM68pdWriteProtect

    beq     @parsed_pmdt                    ; if resident but outside HTAB, put in HTAB
    bltlr   cr7                             ; if no flags, return invalid (GT)
    bl      CrashPageTable                  ; crash hard in any other case

@single_pte ; PMDT_PTE_Single
    ori     r28, r27, 0xfff                 ; r27 = EA, r31 = PMDT (low word, RPN)
    stw     r28, KDP.HtabSingleEA(r1)
    rlwinm  r31, r31, 0, ~(Pattr_NotPTE | Pattr_PTE_Single)  ; clear the flag that got us here, leaving none
    li      r26, 0x5A5A                     ; so that KDP.HtabSinglePTE gets set and we return correctly
    b       @parsed_pmdt                    ; RTS with r26 = 0x5A5A and r31 having flags cleared

@not_actually_paged ; Pattr_NotPTE set, but not PMDT_Paged
    bgtlr                                   ; PMDT_InvalidAddress/PMDT_Available: return invalid (GT)
    addi    r29, r1, KDP.SupervisorSpace
    b       SetSpace                        ; PMDT_Supervisor -> change addr space and return success (EQ)

@pteg_full ; Try the secondary hashing function, if we haven't already
    cmplw   cr6, r28, r26                   ; r26 is as set by PMDT interpretation, r28 = bit 26 of draft PTE r31
    subi    r29, r29, 64 + 16               ; Make r29 the actual PTEG ptr (PTE search code is very tight)
    ble     cr6, @both_ptegs_full           ; Not sure why r26/r28 could force the sec hash to be skipped...

    crnot   cr0_eq, cr0_eq                  ; Flip everything (CR0.EQ means "secondary")
    lwz     r30, KDP.PTEGMask(r1)
    xori    r31, r31, 0x800                 ; Flip PTE bit 20 to signify sec hash func (or back to primary if failing)
    xor     r29, r29, r30                   ; Flip r29 into the sec PTEG ptr (or back to primary if failing)
    beq     @try_secondary_pteg             ; Go back in with CR0.EQ set this time (or fall through...)
                                            ; On fallthru, r29 = prim PTEG ptr

@both_ptegs_full ; So choose a slot in this PTEG to overflow
    lwz     r26, KDP.HtabLastOverflow(r1)   ; this could be zero
    crclr   cr6_eq                          ; cr6.eq means "hell, we're desperate"
    rlwimi  r26, r29, 0, 0xFFFFFFC0         ; r26 points to the PTE we should try to protext from overflow
    addi    r29, r26, 8                     ; r29 points to the following PTE (gets clobbered straight away)
    b       @first_pte
@redo_search                                
    bne     cr6, @nomr
    mr      r26, r29
@nomr
@next_pte
    cmpw    cr6, r29, r26
    addi    r29, r29, 8
@first_pte
    rlwimi  r29, r26, 0, 0xFFFFFFC0
    lwz     r31, 4(r29)
    lwz     r30, 0(r29)
    beq     cr6, @got_pte
    _mvbit0 r28, bUpteHash, r31, bLpteReference
    andc.   r28, r28, r30                   ; Protect if R && !H (i.e. page has been ref'd and primary-hash)
    bne     @next_pte                       ; But otherwise, or if we're desperate, then kick this PTE out!
@got_pte

; Left side: protect PP2=0, KDP and CB from overflow
    clrlwi  r28, r31, 30
    cmpwi   cr7, r28, 0
    clrrwi  r28, r31, 12
    cmpw    r28, r1
    lwz     r30, KDP.ContextPtr(r1)
    beq     cr7, @redo_search   ; if PP1=0
    addi    r31, r30, CB.Size-1
    beq     @redo_search        ; KDP

    rlwinm  r30, r30, 0, 0xFFFFF000
    cmpwi   cr7, r28, 30
    lwz     r30, 0(r29)
    rlwinm  r31, r31, 0, 0xFFFFF000
    cmpwi   r28, 31
                                                rlwinm  r31, r30, 0, 0x00000040 ; To do with below?
    beq     cr7, @redo_search
    extlwi  r28, r30, 4, 1
    beq     @redo_search

; Okay... now do the dirty job of actually overflowing a PTEG (the one at r29)
; (this will mean tweaking the victim PTE's 68k-PD or PTE)
    neg     r31, r31                        ; Inscrutable... extracting PMDT offset?
    insrwi  r28, r30, 6, 4
    xor     r31, r31, r29
    rlwimi  r28, r30, 5, 10, 19
    rlwinm  r31, r31, 6, 10, 19
    xor     r28, r28, r31
    lwz     r26, KDP.CurSpace.SegMapPtr(r1)
    rlwinm  r30, r28, 7, 0x00000078

    lwzx    r26, r26, r30                   ; Hell, get a segment pointer

@oflow_next_pmdt                            ; find the last non-blank PMDT in the segment
    lhz     r30, PMDT.PageIdx(r26)
    rlwinm  r31, r28, 20, 0x0000FFFF
    subf    r30, r30, r31
    lhz     r31, PMDT.PageCount(r26)
    addi    r26, r26, 8
    cmplw   cr7, r30, r31
    lwz     r31, PMDT.Word2 - 8(r26)
    andi.   r31, r31, EveryPattr
    cmpwi   r31, PMDT_Available
    bgt     cr7, @oflow_next_pmdt           ; addr not in this PMDT -> try other PMDT
    beq     @oflow_next_pmdt                ; not PMDT_Available -> try other PMDT

    lwz     r26, PMDT.Word2 - PMDT.Size(r26)  ; If PMDT_Paged then we must wang the 68k-PD pre-return
    slwi    r30, r30, 2                     ; (r30 = 68k-PD offset relative to first in in segment)
    extrwi  r31, r26, 2, 20
    cmpwi   cr7, r31, PMDT_Paged >> 10   ; (save that little tidbit in cr7)

    lwz     r31, KDP.NKInfo.HashTableOverflowCount(r1)
    stw     r29, KDP.HtabLastOverflow(r1)
    addi    r31, r31, 1
    stw     r31, KDP.NKInfo.HashTableOverflowCount(r1)
    lwz     r31, KDP.NKInfo.HashTableDeleteCount(r1)
    stw     r30, 0(r29)                     ; Very clever: save an "invalid" value in PTE then redo search
    addi    r31, r31, 1
    stw     r31, KDP.NKInfo.HashTableDeleteCount(r1)

    sync                                    ; Clear the page from TLB because it could get moved
    tlbie   r28
    sync

    _clrNCBCache scr=r28                    ; Also clobber NCB cache if page could get moved

    bne     cr7, PutPTE                     ; Is this page in a paged area, with a 68k Page Descriptor?
    rlwinm  r26, r26, 22, 0xFFFFFFFC        ; r26 = RPN * 4
    lwzux   r28, r26, r30                   ; (the 68k-PD to edit)
    lwz     r31, 4(r29)                     ; (extract some info from the lower PTE before discarding)
    andi.   r30, r28, M68pdInHTAB           ; Crash if this 68k-PD wasn't marked as HTAB'd!
    rlwinm  r30, r28, 32-9, 0x007FFFF8
    xor     r30, r30, r29                   ; Crash if this 68k-PD's pointer didn't match this PTE!
    beq     CrashPageTable
    andi.   r30, r30, 0xffff
    xori    r28, r28, M68pdInHTAB           ; Edit the 68k-PD's HTAB flag, physical ptr, and "usage" flags
    bne     CrashPageTable
    rlwimi  r28, r31, 0, 0xFFFFF000
    _mvbit  r28, bM68pdModified, r31, bLpteChange
    _mvbit  r28, bM68pdUsed, r31, bLpteReference
    stw     r28, 0(r26)                     ; Save edited 68k-PD

    b       PutPTE                          ; PTEG overflow complete. Redo PutPTE!

########################################################################

SetSpace ; Space r29
; The passed in record points to a segment map, which in turn has 16
; pointers into the global PageMap, where we will find the PMDTs for
; the segment. It also contains a BAT map, which contains four 4-bit
; offsets into the global BatRange array, where we will find BAT reg
; values. Our job here is just to set the Segment Registers and BAT
; registers.

    sync
    lwz     r28, AddrSpace.SegMapPtr(r29)
    stw     r28, KDP.CurSpace.SegMapPtr(r1)
    addi    r28, r28, 16*8 + 4
    lis     r31, 0

@next_seg                               ; segment registers
    lwzu    r30, -8(r28)
    subis   r31, r31, 0x1000
    mr.     r31, r31
    mtsrin  r30, r31
    bne     @next_seg

    mfpvr   r31
    lwz     r28, AddrSpace.BatMap(r29)
    andis.  r31, r31, 0xFFFE
    addi    r29, r1, 0
    stw     r28, KDP.CurSpace.BatMap(r1)
    beq     @601

    li      r30, 0                      ; bad BATs are *never* legal,
    mtspr   ibat0u, r30                 ; so zero before setting
    mtspr   ibat1u, r30
    mtspr   ibat2u, r30
    mtspr   ibat3u, r30
    mtspr   dbat0u, r30
    mtspr   dbat1u, r30
    mtspr   dbat2u, r30
    mtspr   dbat3u, r30

    rlwimi  r29, r28, 7, 0x00000078     ; BATS, non-601
    lwz     r31, KDP.BatRanges + 4(r29)
    lwz     r30, KDP.BatRanges + 0(r29)
    rlwinm  r31, r31, 0, ~0x00000008
    mtspr   ibat0l, r31
    mtspr   ibat0u, r30
    stw     r31, KDP.CurIBAT0.L(r1)
    stw     r30, KDP.CurIBAT0.U(r1)

    rlwimi  r29, r28, 11, 0x00000078
    lwz     r31, KDP.BatRanges + 4(r29)
    lwz     r30, KDP.BatRanges + 0(r29)
    rlwinm  r31, r31, 0, ~0x00000008
    mtspr   ibat1l, r31
    mtspr   ibat1u, r30
    stw     r31, KDP.CurIBAT1.L(r1)
    stw     r30, KDP.CurIBAT1.U(r1)

    rlwimi  r29, r28, 15, 0x00000078
    lwz     r31, KDP.BatRanges + 4(r29)
    lwz     r30, KDP.BatRanges + 0(r29)
    rlwinm  r31, r31, 0, ~0x00000008
    mtspr   ibat2l, r31
    mtspr   ibat2u, r30
    stw     r31, KDP.CurIBAT2.L(r1)
    stw     r30, KDP.CurIBAT2.U(r1)

    rlwimi  r29, r28, 19, 0x00000078
    lwz     r31, KDP.BatRanges + 4(r29)
    lwz     r30, KDP.BatRanges + 0(r29)
    rlwinm  r31, r31, 0, ~0x00000008
    mtspr   ibat3l, r31
    mtspr   ibat3u, r30
    stw     r31, KDP.CurIBAT3.L(r1)
    stw     r30, KDP.CurIBAT3.U(r1)

    rlwimi  r29, r28, 23, 0x00000078
    lwz     r31, KDP.BatRanges + 4(r29)
    lwz     r30, KDP.BatRanges + 0(r29)
    mtspr   dbat0l, r31
    mtspr   dbat0u, r30
    stw     r31, KDP.CurDBAT0.L(r1)
    stw     r30, KDP.CurDBAT0.U(r1)

    rlwimi  r29, r28, 27, 0x00000078
    lwz     r31, KDP.BatRanges + 4(r29)
    lwz     r30, KDP.BatRanges + 0(r29)
    mtspr   dbat1l, r31
    mtspr   dbat1u, r30
    stw     r31, KDP.CurDBAT1.L(r1)
    stw     r30, KDP.CurDBAT1.U(r1)

    rlwimi  r29, r28, 31, 0x00000078
    lwz     r31, KDP.BatRanges + 4(r29)
    lwz     r30, KDP.BatRanges + 0(r29)
    mtspr   dbat2l, r31
    mtspr   dbat2u, r30
    stw     r31, KDP.CurDBAT2.L(r1)
    stw     r30, KDP.CurDBAT2.U(r1)

    rlwimi  r29, r28, 3, 0x00000078
    lwz     r31, KDP.BatRanges + 4(r29)
    lwz     r30, KDP.BatRanges + 0(r29)
    mtspr   dbat3l, r31
    mtspr   dbat3u, r30
    stw     r31, KDP.CurDBAT3.L(r1)
    stw     r30, KDP.CurDBAT3.U(r1)

    isync
    cmpw    r29, r29                    ; return EQ for PutPTE
    blr

@601
    rlwimi  r29, r28, 7, 0x00000078
    lwz     r30, KDP.BatRanges + 0(r29)
    lwz     r31, KDP.BatRanges + 4(r29)
    stw     r30, KDP.CurIBAT0.U(r1)
    stw     r31, KDP.CurIBAT0.L(r1)
    stw     r30, KDP.CurDBAT0.U(r1)
    stw     r31, KDP.CurDBAT0.L(r1)
    rlwimi  r30, r31, 0, 25, 31         ; swap bits 25-31 of U/L BATs!
    mtspr   ibat0u, r30
    lwz     r30, KDP.BatRanges + 0(r29)
    rlwimi  r31, r30, 30, 26, 31
    rlwimi  r31, r30, 6, 25, 25
    mtspr   ibat0l, r31

    rlwimi  r29, r28, 11, 0x00000078
    lwz     r30, KDP.BatRanges + 0(r29)
    lwz     r31, KDP.BatRanges + 4(r29)
    stw     r30, KDP.CurIBAT1.U(r1)
    stw     r31, KDP.CurIBAT1.L(r1)
    stw     r30, KDP.CurDBAT1.U(r1)
    stw     r31, KDP.CurDBAT1.L(r1)
    rlwimi  r30, r31, 0, 25, 31
    mtspr   ibat1u, r30
    lwz     r30, KDP.BatRanges + 0(r29)
    rlwimi  r31, r30, 30, 26, 31
    rlwimi  r31, r30, 6, 25, 25
    mtspr   ibat1l, r31

    rlwimi  r29, r28, 15, 0x00000078
    lwz     r30, KDP.BatRanges + 0(r29)
    lwz     r31, KDP.BatRanges + 4(r29)
    stw     r30, KDP.CurIBAT2.U(r1)
    stw     r31, KDP.CurIBAT2.L(r1)
    stw     r30, KDP.CurDBAT2.U(r1)
    stw     r31, KDP.CurDBAT2.L(r1)
    rlwimi  r30, r31, 0, 25, 31
    mtspr   ibat2u, r30
    lwz     r30, KDP.BatRanges + 0(r29)
    rlwimi  r31, r30, 30, 26, 31
    rlwimi  r31, r30, 6, 25, 25
    mtspr   ibat2l, r31

    rlwimi  r29, r28, 19, 0x00000078
    lwz     r30, KDP.BatRanges + 0(r29)
    lwz     r31, KDP.BatRanges + 4(r29)
    stw     r30, KDP.CurIBAT3.U(r1)
    stw     r31, KDP.CurIBAT3.L(r1)
    stw     r30, KDP.CurDBAT3.U(r1)
    stw     r31, KDP.CurDBAT3.L(r1)
    rlwimi  r30, r31, 0, 25, 31
    mtspr   ibat3u, r30
    lwz     r30, KDP.BatRanges + 0(r29)
    rlwimi  r31, r30, 30, 26, 31
    rlwimi  r31, r30, 6, 25, 25
    mtspr   ibat3l, r31

    cmpw    r29, r29
    blr

########################################################################

GetPhysical ; EA r27, batPtr r29 // PA r31, EQ=Fail
    lwz     r30, 0(r29)
    li      r28, -1
    rlwimi  r28, r30, 15, 0, 14
    xor     r31, r27, r30
    andc.   r31, r31, r28
    beq     @gotbat
    lwzu    r30, 8(r29)
    rlwimi  r28, r30, 15, 0, 14
    xor     r31, r27, r30
    andc.   r31, r31, r28
    beq     @gotbat
    lwzu    r30, 8(r29)
    rlwimi  r28, r30, 15, 0, 14
    xor     r31, r27, r30
    andc.   r31, r31, r28
    beq     @gotbat
    lwzu    r30, 8(r29)
    rlwimi  r28, r30, 15, 0, 14
    xor     r31, r27, r30
    andc.   r31, r31, r28
    bne     GetPhysicalFromHTAB
@gotbat
    andi.   r31, r30, 1
    rlwinm  r28, r28, 0, 8, 19
    lwzu    r31, 4(r29)
    and     r28, r27, r28
    or      r31, r31, r28
    bnelr

GetPhysicalFromHTAB ; EA r27 // PA r31, EQ=Fail
; Calculate hash
    mfsrin  r31, r27
    rlwinm  r30, r27, 10, UpteAPI
    rlwimi  r30, r31, 7, UpteVSID
    rlwinm  r28, r27, 26, 10, 25
    _ori    r30, r30, UpteValid
    rlwinm  r31, r31, 6, 7, 25
    xor     r28, r28, r31
    lwz     r31, KDP.PTEGMask(r1)
    lwz     r29, KDP.HTABORG(r1)
    and     r28, r28, r31
    or.     r29, r29, r28
@secondary_hash
    lwz     r31, 0(r29)
    lwz     r28, 8(r29)
    cmpw    cr6, r30, r31
    lwz     r31, 16(r29)
    cmpw    cr7, r30, r28
    lwzu    r28, 24(r29)
    bne     cr6, @keep_going
@found_pte
    lwzu    r31, -0x0014(r29)
    blr
@keep_going
    cmpw    cr6, r30, r31
    lwzu    r31, 8(r29)
    beq     cr7, @found_pte
    cmpw    cr7, r30, r28
    lwzu    r28, 8(r29)
    beq     cr6, @found_pte
    cmpw    cr6, r30, r31
    lwzu    r31, 8(r29)
    beq     cr7, @found_pte
    cmpw    cr7, r30, r28
    lwzu    r28, 8(r29)
    beq     cr6, @found_pte
    cmpw    cr6, r30, r31
    lwzu    r31, -12(r29)
    beqlr   cr7
    cmpw    cr7, r30, r28
    lwzu    r31, 8(r29)
    beqlr   cr6
    lwzu    r31, 8(r29)
    beqlr   cr7
    lwz     r31, KDP.PTEGMask(r1)
    xori    r30, r30, UpteHash
    andi.   r28, r30, UpteHash
    subi    r29, r29, 60
    xor     r29, r29, r31
    bne     @secondary_hash
    blr

########################################################################

FlushTLB
    lhz     r29, KDP.ProcInfo.TransCacheTotalSize(r1)
    slwi    r29, r29, 11
@loop
    subi    r29, r29, 4096
    cmpwi   r29, 0
    tlbie   r29
    bgt     @loop
    sync
    blr
