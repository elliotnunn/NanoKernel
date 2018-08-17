; Legacy 68k Virtual Memory interface, accessed via 68k FE0A trap

kMaxVirtualSegments equ 4
kMinIOSegment equ 8

########################################################################

KCallVMDispatch
    stw     r7, KDP.Flags(r1)
    lwz     r7, KDP.CodeBase(r1)
    cmplwi  r3, (VMTabEnd-VMTab)/2
    insrwi  r7, r3, 7, 24
    lhz     r8, VMTab-CodeBase(r7)
    lwz     r9, KDP.VMLogicalPages(r1)
    add     r8, r8, r7
    mtlr    r8

    lwz     r6, KDP.r6(r1)
    stw     r14, KDP.r14(r1)
    stw     r15, KDP.r15(r1)
    stw     r16, KDP.r16(r1)

    bltlr
    b       vmRetNeg1

VMTab
    MACRO
    vmtabLine &label
    DC.W (&label-CodeBase) - (* - VMtab)
    ENDM

    vmtabLine   VMInit                              ;  0 init the MMU virtual space
    vmtabLine   vmRet;VMUnInit                      ;  1 un-init the MMU virtual space
    vmtabLine   vmRet;VMFinalInit                   ;  2 last chance to init after new memory dispatch is installed
    vmtabLine   VMIsResident                        ;  3 ask about page status
    vmtabLine   VMIsUnmodified                      ;  4 ask about page status
    vmtabLine   VMIsInited                          ;  5 ask about page status
    vmtabLine   VMShouldClean                       ;  6 ask about page status
    vmtabLine   VMMarkResident                      ;  7 set page status 
    vmtabLine   VMMarkBacking                       ;  8 set page status
    vmtabLine   VMMarkCleanUnused                   ;  9 set page status
    vmtabLine   VMGetPhysicalPage                   ; 10 return phys page given log page
    vmtabLine   vmRetNeg1;VMGetPhysicalAddress      ; 11 return phys address given log page (can be different from above!)
    vmtabLine   VMExchangePages                     ; 12 exchange physical page contents
    vmtabLine   vmRet;VMReload                      ; 13 reload the ATC with specified page
    vmtabLine   vmRet;VMFlushAddressTranslationCache; 14 just do it
    vmtabLine   vmRet;VMFlushDataCache              ; 15 wack the data cache
    vmtabLine   vmRet;VMFlushCodeCache              ; 16 wack the code cache
    vmtabLine   VMMakePageCacheable                 ; 17 make it so...
    vmtabLine   VMMakePageNonCacheable              ; 18 make it so...
    vmtabLine   VMGetPTEntryGivenPage               ; 19 given a page, get its 68K PTE
    vmtabLine   VMSetPTEntryGivenPage               ; 20 given a page & 68K pte, set the real PTE
    vmtabLine   VMPTest                             ; 21 ask why we got this page fault
    vmtabLine   VMLRU                               ; 22 sweep pages for least recently used ones
    vmtabLine   VMMarkUndefined                     ; 23
    vmtabLine   VMMakePageWriteThrough              ; 24
    vmtabLine   VMAllocateMemory                    ; 25 create logical area by stealing from "high memory"
VMTabEnd

########################################################################

vmRetNeg1
    li      r3, -1
    b       vmRet
vmRet0
    li      r3, 0
    b       vmRet
vmRet1
    li      r3, 1
vmRet
    lwz     r14, KDP.r14(r1)
    lwz     r15, KDP.r15(r1)
    lwz     r16, KDP.r16(r1)
    lwz     r7, KDP.Flags(r1)
    lwz     r6, KDP.ContextPtr(r1)
    b       ReturnFromInt

########################################################################

VMInit ; logicalpages a0/r4, pagearray (logical ptr) a1/r5
; Switch the kernel's internal array of 68k Page Descriptors to the larger one provided.
    lwz     r7, KDP.VMPageArray(r1)         ; Return failure code if VM is already running
    lwz     r8, KDP.PhysicalPageArray(r1)
    cmpw    r7, r8
    bne     vmRet1

; Edit PMDTs to point to the pre-VM PhysicalPageArray. Also boot every page
; from the HTAB so we can easily work with 68k Page Descriptors.
; (many sanity checks!)
    stw     r4, KDP.VMLogicalPages(r1)      ; Set these globals now, because the loop will
    stw     r5, KDP.VMPageArray(r1)         ; clobber the registers.
    lwz     r6, KDP.CurSpace.SegMapPtr(r1)
    li      r5, 0                           ; r5 = current segment number
    li      r4, 0                           ; r4 = current page number
@segloop
    lwz     r8, 0(r6)                       ; load this segment's first PMDT and get all its info
    addi    r6, r6, 8
    lhz     r3, PMDT.PageIdx(r8)
    lhz     r7, PMDT.PageCount(r8)
    lwz     r8, PMDT.Word2(r8)
    addi    r7, r7, 1
    cmpwi   cr1, r3, 0
    andi.   r3, r8, PMDT_Paged
    cmpwi   r3, PMDT_Paged
    bne     @skip_segment                   ; (skip segment if not paged!)
    bnel    cr1, CrashVirtualMem            ; (first PMDT in segment must start at offset 0!)

    rlwinm  r15, r8, 32-10, ~(PMDT_Paged>>10); seg's PhysicalPageArray ptr := PMDT's RPN, times 4
    addi    r3, r1, KDP.PhysicalPageArray
    rlwimi  r3, r5, 2, 0x0000000C
    stw     r15, 0(r3)

    slwi    r3, r5, 16                      ; (confirm that the inner loop is synced with the outer loop)
    cmpw    r3, r4
    bnel    CrashVirtualMem

@pageloop
    lwz     r16, 0(r15)
    subi    r7, r7, 1
    andi.   r3, r16, M68pdResident          ; all pages must be resident before VM starts
    beql    CrashVirtualMem
    andi.   r3, r16, M68pdInHTAB            ; (if page is in htab, check the pte and remove)
    beq     @not_in_htab

    lwz     r14, KDP.HTABORG(r1)            ; get pte into the usual r8/r9
    rlwinm  r3, r16, 23, 9, 28
    lwzux   r8, r14, r3
    lwz     r9, 4(r14)
    andis.  r3, r8, 0x8000;UpteValid        ; that pte must be valid, and one of P0/P1 must be set!
    beql    CrashVirtualMem
    andi.   r3, r9, LpteP0 | LpteP1
    cmpwi   r3, 0
    beql    CrashVirtualMem
    rlwinm  r3, r16, 17, 22, 31             ; bits 7-16 of the 68k Page Descriptor (<= MYSTERIOUS)
    rlwimi  r3, r8, 10, 16, 21              ; API from Upte
    rlwimi  r3, r8, 21, 12, 15              ; top 4 bits of VSID
    cmpw    r3, r4                          ; why would we compare this to r4, our inner loop counter?
    bnel    CrashVirtualMem
    bl      DeletePTE
@not_in_htab
    cmpwi   r7, 0
    addi    r15, r15, 4
    addi    r4, r4, 1
    bne     @pageloop

@skip_segment ; because PMDT is not paged
    addi    r5, r5, 1
    cmpwi   r5, kMaxVirtualSegments
    bne     @segloop

    lwz     r7, KDP.VMPhysicalPages(r1)     ; (final check: did we actually iterate over every page in the VM area?)
    cmpw    r4, r7
    bnel    CrashVirtualMem
    lwz     r5, KDP.VMPageArray(r1)         ; Restore the two arguments that this loop clobbered
    lwz     r4, KDP.VMLogicalPages(r1)

; Do some checks. (no need to crash the kernel if these fail)
    andi.   r7, r5, 0xfff                   ; If new VMPageArray is not page-aligned...
    li      r3, 2
    bne     @fail                           ;    ...fail 2
    lis     r7, kMaxVirtualSegments         ; If new VM area is too big ...
    cmplw   r7, r4
    li      r3, 3
    blt     @fail                           ;    ...fail 3
    addi    r7, r4, 0x3ff                   ; If (logical pages up to and including the page array) > (physical pages)...
    srwi    r6, r7, 10
    srwi    r8, r5, 12
    add     r8, r8, r6
    lwz     r9, KDP.VMPhysicalPages(r1)
    cmplw   r8, r9
    li      r3, 4
    bgt     @fail                           ;    ...fail 4
    cmplw   r4, r9                          ; If PHYS > LOG...
    li      r3, 5
    blt     @fail                           ;    ...fail 5
    srwi    r7, r5, 12                      ; *Physicalize VMPageArray*
    bl      vmInitGetPhysical
    stw     r9, KDP.VMPageArray(r1)
    mr      r15, r9                         ; If VMPageArray seems to be discontiguous...
    srwi    r7, r5, 12
    add     r7, r7, r6
    subi    r7, r7, 1
    bl      vmInitGetPhysical
    subf    r9, r15, r9
    srwi    r9, r9, 12
    addi    r9, r9, 1
    cmpw    r9, r6
    li      r3, 6
    bne     @fail                           ;     ...fail 6

; Init the new VMPageArray (userspace just provides the buffer)
    stw     r4, KDP.VMLogicalPages(r1)      ; (Good time to adjust NKSystemInfo value)
    slwi    r7, r4, 12
    stw     r7, KDP.SysInfo.LogicalMemorySize(r1)

    slwi    r7, r4, 2                       ; First make every page non-resident (zero)
    li      r8, 0
@nonresloop
    subi    r7, r7, 4
    cmpwi   r7, 0
    stwx    r8, r15, r7
    bne     @nonresloop
    lwz     r7, KDP.VMPhysicalPages(r1)     ; Then make the original logical area resident again
    slwi    r6, r7, 2                       ; (uses backed-up PhysicalPageArray)
@resloop
    subi    r6, r6, 4
    srwi    r7, r6, 2
    bl      vmInitGetPhysical
    cmpwi   r6, 0
    ori     r16, r9, M68pdCacheNotIO | M68pdResident
    stwx    r16, r15, r6
    bne     @resloop

; Ensure that VMPageArray is resident, and wire it down
    lwz     r15, KDP.VMPageArray(r1)
    srwi    r7, r5, 10
    add     r15, r15, r7
    lwz     r5, KDP.VMLogicalPages(r1)
@checkloop
    lwz     r16, 0(r15)
    andi.   r7, r16, M68pdResident
    beql    CrashVirtualMem
    ori     r16, r16, M68pdGlobal | M68pdWriteProtect
    stw     r16, 0(r15)
    subi    r5, r5, 1024
    cmpwi   r5, 0
    addi    r15, r15, 4
    bgt     @checkloop

; Point the paged PMDTs in the PageMap to the new VMPageArray
    lwz     r6, KDP.CurSpace.SegMapPtr(r1)  ; Clear the first two PMDTs of segs 0-3
    li      r9, 0
    ori     r7, r9, 0xffff                  ; (first word: whole-segment)
    li      r8, PMDT_InvalidAddress         ; (second word: PMDT_InvalidAddress)
@pmdtresetloop
    lwz     r3, 0(r6)
    addi    r6, r6, 8
    stw     r7, 0(r3)
    stw     r8, 4(r3)
    stw     r7, 8(r3)
    stw     r8, 12(r3)
    addi    r9, r9, 1
    cmpwi   r9, kMaxVirtualSegments - 1
    ble     @pmdtresetloop

    lwz     r6, KDP.CurSpace.SegMapPtr(r1)  ; Edit PMDTs to point to the new PD Array
    lwz     r9, KDP.VMLogicalPages(r1)
    lwz     r15, KDP.VMPageArray(r1)
@loop
    lwz     r8, 0(r6)                       ; r8 = PMDT ptr
    lis     r7, 1                           ; r9 fallback on 256 MB
    rlwinm. r3, r9, 16, 0x0000FFFF          ; test VMLogicalPages
    bne     @on
    mr      r7, r9                          ; prefer r9 = VMLogicalPages
@on
    subf.   r9, r7, r9
    subi    r7, r7, 1
    stw     r7, 0(r8)
    rlwinm  r7, r15, 10, ~PMDT_Paged
    ori     r7, r7, PMDT_Paged
    stw     r7, 4(r8)
    addis   r15, r15, 4
    addi    r6, r6, 8
    bne     @loop

; Done!
    b       vmRet0

@fail ; This code path seems to leave the system in a usable state.
    lwz     r7, KDP.VMPhysicalPages(r1)     
    lwz     r8, KDP.PhysicalPageArray(r1)
    stw     r7, KDP.VMLogicalPages(r1)
    stw     r8, KDP.VMPageArray(r1)
    b       vmRet

########################################################################

VMExchangePages ; page1 a0/r4, page2 a1/r5
    bl      PageInfo
    bc      BO_IF_NOT, cr4_lt, vmRetNeg1                ; not a paged area
    bc      BO_IF, 21, vmRetNeg1
    bc      BO_IF_NOT, bM68pdResident, vmRetNeg1        ; must be resident
    bc      BO_IF, bM68pdCacheinhib, vmRetNeg1          ; must not have special properties
    bc      BO_IF_NOT, bM68pdCacheNotIO, vmRetNeg1
    bcl     BO_IF, bM68pdInHTAB, DeletePTE              ; if in HTAB, must be removed
    mr      r6, r15                                     ; r6 = src 68k PTE ptr

    mr      r4, r5
    mr      r5, r16                                     ; r5 = src 68k PTE
    lwz     r9, KDP.VMLogicalPages(r1)
    bl      PageInfo
    bc      BO_IF_NOT, cr4_lt, vmRetNeg1
    bc      BO_IF, 21, vmRetNeg1
    bc      BO_IF_NOT, bM68pdResident, vmRetNeg1
    bc      BO_IF, bM68pdCacheinhib, vmRetNeg1
    bc      BO_IF_NOT, bM68pdCacheNotIO, vmRetNeg1
    bcl     BO_IF, bM68pdInHTAB, DeletePTE

    stw     r5, 0(r15)                                  ; swap 68k PTEs (in that big flat list)                                  
    stw     r16, 0(r6)

    rlwinm  r4, r5, 0, 0xFFFFF000                       ; get clean physical ptrs to both pages
    rlwinm  r5, r16, 0, 0xFFFFF000

    li      r9, 0x1000
    li      r6, 4
@copyloop
    subf.   r9, r6, r9
    lwzx    r7, r4, r9
    lwzx    r8, r5, r9
    stwx    r7, r5, r9
    stwx    r8, r4, r9
    bne     @copyloop

    b       vmRet

########################################################################

VMGetPhysicalPage ; page a0/r4 // p_page d0/r3
    bl      PageInfo
    bc      BO_IF_NOT, bM68pdResident, vmRetNeg1
    srwi    r3, r9, 12
    b       vmRet

########################################################################

VMGetPTEntryGivenPage ; page a0/r4 // 68kpte d0/r3
; Get a page's 68k Page Descriptor
    bl      PageInfo
    mr      r3, r16
    bc      BO_IF_NOT, bM68pdResident, vmRet
    rlwimi  r3, r9, 0, 0xFFFFF000 ; Insert PowerPC information if needed
    b       vmRet

########################################################################

VMIsInited ; page a0/r4 // bool d0/r3
; An uninited page is not resident and does not have its Inited bit set
    bl      PageInfo
    bc      BO_IF, bM68pdResident, vmRet1
    _mvbit0 r3, 31, r16, bM68pdInited
    b       vmRet

########################################################################

VMIsResident ; page a0/r4 // bool d0/r3
    bl      PageInfo
    rlwinm  r3, r16, 0, 1 ; M68pdResident
    b       vmRet

########################################################################

VMIsUnmodified ; page a0/r4 // bool d0/r3
    bl      PageInfo
    _mvbit0 r3, 31, r16, bM68pdModified
    xori    r3, r3, 1
    b       vmRet

########################################################################

VMLRU ; Save Used bit of every resident page and clear originals
    slwi.   r9, r9, 2                   ; (r9 is VMLogicalPages)
    lwz     r15, KDP.VMPageArray(r1)
    lwz     r14, KDP.HTABORG(r1)
    add     r15, r15, r9                ; r15 = loop PageArray ptr
    srwi    r4, r9, 2                   ; r4 = loop counter

    li      r5, LpteReference           ; r5/r6 or clearing bits with andc
    li      r6, M68pdUsed

@loop ; over every logical page
    lwzu    r16, -4(r15)
    subi    r4, r4, 1
    mtcr    r16
    cmpwi   r4, 0

    rlwinm  r7, r16, 23, 0x007FFFF8     ; r7 = offset of PPC PTE (if any)
    bc      BO_IF_NOT, bM68pdResident, @nonresident

    bc      BO_IF_NOT, bM68pdInHTAB, @not_in_htab
    add     r14, r14, r7                ; If PPC PTE in HTAB, copy its Ref
    lwz     r9, 4(r14)                  ; bit back to 68k PTE and clear
    _mvbit  r16, bM68pdUsed, r9, bLpteReference
    andc    r9, r9, r5
    bl      SaveLowerPTE
    subf    r14, r7, r14
@not_in_htab

    _mvbit  r16, bM68pdFrozenUsed, r16, bM68pdUsed
    andc    r16, r16, r6                ; save Used and clear original
    stw     r16, 0(r15)                 ; save changed 68k PTE
@nonresident

    bne     @loop
    b       vmRet

########################################################################

VMMakePageCacheable ; page a0/r4
; Switch off the special cache-skipping behaviour for stores and loads:
; PPC: LpteWritethru(W)=0, LpteInhibcache(I)=0
; 68k: M68pdCacheNotIO(CM0)=1, M68pdCacheinhib(CM1)=0 ["Cachable,Copyback"]
    bl      PageInfo
    rlwinm  r7, r16, 0, M68pdCacheNotIO | M68pdCacheinhib   ; test CM0/CM1
    cmpwi   r7, M68pdCacheNotIO
    bc      BO_IF_NOT, bM68pdResident, vmRetNeg1            ; not resident!
    beq     vmRet                                           ; already write-through
    bc      BO_IF_NOT, cr4_lt, vmMakePageCacheableForIO     ; not a paged area, so for I/O

    bcl     BO_IF_NOT, bM68pdInHTAB, QuickCalcPTE           ; need to have a PPC PTE

    rlwinm  r16, r16, 0, ~(M68pdCacheinhib | M68pdCacheNotIO)
    rlwinm  r9, r9,  0, ~(LpteWritethru | LpteInhibcache)
    lwz     r7, KDP.PageAttributeInit(r1)
    rlwimi  r9, r7, 0, LpteMemcoher | LpteGuardwrite
    ori     r16, r16, M68pdCacheNotIO
    bl      SavePTEAnd68kPD

    b       vmRet

vmMakePageCacheableForIO ; need to edit a PMDT directly (code copied from VMMakePageWriteThrough below!)
    rlwinm  r7, r4, 16, 0xF
    cmpwi   r7, kMinIOSegment
    blt     vmRetNeg1

    bc      BO_IF_NOT, bM68pdCacheinhib, vmRetNeg1          ; I/O space is always cache-inhibited

    lwz     r5, PMDT.Size + PMDT.Word2(r15)                 ; take over the following PMDT if
    andi.   r6, r5, EveryPattr                              ; it is "available"
    cmpwi   r6, PMDT_Available
    beq     @next_pmdt_free

; no free PMDT... hijack the previous one if it is PMDT_PTE_Range
    subi    r15, r15, PMDT.Size
    lwz     r5, PMDT.Word2(r15)
    lhz     r6, PMDT.PageIdx(r15)
    andi.   r5, r5, Pattr_NotPTE | Pattr_PTE_Single
    lhz     r5, PMDT.PageCount(r15)
    bne     vmRetNeg1                                       ; demand PMDT_PTE_Range
    addi    r5, r5, 1
    add     r6, r6, r5
    xor     r6, r6, r4
    andi.   r6, r6, 0xffff                                  ; does the previous PMDT abut this one?
    bne     vmRetNeg1
    sth     r5, PMDT.PageCount(r15)
    b       vmCleanupTrashedPMDT

@next_pmdt_free ; so replace it with copy of current one, then turn current one into PMDT_PTE_Range
    lwz     r5, 0(r15)                                      ; copy current PMDT to next
    lwz     r6, 4(r15)
    stw     r5, PMDT.Size + 0(r15)
    stw     r6, PMDT.Size + 4(r15)

    slwi    r5, r4, 16                                      ; PMDT PageIdx=this, PageCount=single
    stw     r5, 0(r15)
    slwi    r5, r4, 12                                      ; PMDT RPN = logical address of page
    ori     r5, r5, LpteP0                                  ; and raise these flags too
    stw     r5, PMDT.Word2(r15)

    b       vmCleanupTrashedPMDT

########################################################################

VMMakePageWriteThrough ; page a0/r4
; Make stores to this page hit the bus straight away:
; PPC: LpteWritethru(W)=1, LpteInhibcache(I)=0
; 68k: M68pdCacheNotIO(CM0)=0, M68pdCacheinhib(CM1)=0 ["Cachable,Write-through"]
    bl      PageInfo
    rlwinm. r7, r16, 0, M68pdCacheNotIO | M68pdCacheinhib   ; test CM0/CM1
    bc      BO_IF_NOT, bM68pdResident, vmRetNeg1            ; not resident!
    beq     vmRet                                           ; already write-through
    bc      BO_IF_NOT, cr4_lt, vmMakePageWriteThroughForIO  ; not a paged area, so for I/O

    bcl     BO_IF_NOT, bM68pdInHTAB, QuickCalcPTE           ; need to have a PPC PTE

    rlwinm  r16, r16, 0, ~(M68pdCacheNotIO | M68pdCacheinhib)
    rlwinm  r9, r9, 0, ~(LpteWritethru | LpteInhibcache)
    ori     r9, r9, LpteWritethru
    bl      SavePTEAnd68kPD

    b       vmFlushPageAndReturn

vmMakePageWriteThroughForIO ; need to edit a PMDT directly
    rlwinm  r7, r4, 16, 0xF
    cmpwi   r7, kMinIOSegment
    blt     vmRetNeg1

    bc      BO_IF_NOT, bM68pdCacheinhib, vmRetNeg1          ; I/O space is always cache-inhibited

    lwz     r5, PMDT.Size + PMDT.Word2(r15)                 ; take over the following PMDT if
    andi.   r6, r5, EveryPattr                              ; it is "available"
    cmpwi   r6, PMDT_Available
    beq     @next_pmdt_free

; no free PMDT... hijack the previous one if it is PMDT_PTE_Range
    subi    r15, r15, PMDT.Size
    lwz     r5, PMDT.Word2(r15)
    lhz     r6, PMDT.PageIdx(r15)
    andi.   r5, r5, Pattr_NotPTE | Pattr_PTE_Single
    lhz     r5, PMDT.PageCount(r15)
    bne     vmRetNeg1                                       ; demand PMDT_PTE_Range
    addi    r5, r5, 1
    add     r6, r6, r5
    xor     r6, r6, r4
    andi.   r6, r6, 0xffff                                  ; does the previous PMDT abut this one?
    bne     vmRetNeg1
    sth     r5, PMDT.PageCount(r15)
    b       vmCleanupTrashedPMDT

@next_pmdt_free ; so replace it with copy of current one, then turn current one into PMDT_PTE_Range
    lwz     r5, 0(r15)                                      ; copy current PMDT to next
    lwz     r6, 4(r15)
    stw     r5, PMDT.Size + 0(r15)
    stw     r6, PMDT.Size + 4(r15)

    slwi    r5, r4, 16                                      ; PMDT PageIdx=this, PageCount=single
    stw     r5, 0(r15)
    slwi    r5, r4, 12                                      ; PMDT RPN = logical address of page
    ori     r5, r5, LpteWritethru | LpteP0                  ; and raise these flags too
    stw     r5, PMDT.Word2(r15)

########################################################################

vmCleanupTrashedPMDT ; we stole a PMDT, so trash any PTE based on the original
    lwz     r15, KDP.PTEGMask(r1)                           ; hash to find the PTEG
    lwz     r14, KDP.HTABORG(r1)
    slwi    r6, r4, 12
    mfsrin  r6, r6
    rlwinm  r8, r6, 7, 0xFFFFF800
    xor     r6, r6, r4
    slwi    r7, r6, 6
    and     r15, r15, r7
    rlwimi  r8, r4, 22, UpteAPI
    crset   cr0_eq                                          ; clear cr0_eq when trying the secondary hash
    _ori    r8, r8, UpteValid                               ; r8 = the exact upper PTE word to search

@secondary_hash
    lwzux   r7, r14, r15                                    ; search the primary or secondary PTEG for r8
    lwz     r15, 8(r14)
    lwz     r6, 16(r14)
    lwz     r5, 24(r14)
    cmplw   cr1, r7, r8
    cmplw   cr2, r15, r8
    cmplw   cr3, r6, r8
    cmplw   cr4, r5, r8
    beq     cr1, @pte_at_r14
    beq     cr2, @pte_at_r14_plus_8
    beq     cr3, @pte_at_r14_plus_16
    beq     cr4, @pte_at_r14_plus_24
    lwzu    r7, 32(r14)
    lwz     r15, 8(r14)
    lwz     r6, 16(r14)
    lwz     r5, 24(r14)
    cmplw   cr1, r7, r8
    cmplw   cr2, r15, r8
    cmplw   cr3, r6, r8
    cmplw   cr4, r5, r8
    beq     cr1, @pte_at_r14
    beq     cr2, @pte_at_r14_plus_8
    beq     cr3, @pte_at_r14_plus_16
    beq     cr4, @pte_at_r14_plus_24

    crnot   cr0_eq, cr0_eq                                  ; can't find it => try again with secondary hash
    lwz     r15, KDP.PTEGMask(r1)
    lwz     r14, KDP.HTABORG(r1)
    slwi    r6, r4, 12
    mfsrin  r6, r6
    xor     r6, r6, r4
    not     r6, r6
    slwi    r7, r6, 6
    and     r15, r15, r7
    xori    r8, r8, UpteHash
    bc      BO_IF_NOT, cr0_eq, @secondary_hash
    b       vmRet

@pte_at_r14_plus_24
    addi    r14, r14, 8
@pte_at_r14_plus_16
    addi    r14, r14, 8
@pte_at_r14_plus_8
    addi    r14, r14, 8
@pte_at_r14                                                 ; found PTE based on original PMDT => delete it
    li      r8, 0
    li      r9, 0
    bl      SavePTE
    b       vmRet

########################################################################

VMMakePageNonCacheable ; page a0/r4
; Make stores and loads hit memory straight away:
; PPC: LpteWritethru(W)=1, LpteInhibcache(I)=1
; 68k: M68pdCacheNotIO(CM0)=0, M68pdCacheinhib(CM1)=0 ["Noncachable"]
    bl      PageInfo
    rlwinm  r7, r16, 0, M68pdCacheNotIO | M68pdCacheinhib
    cmpwi   r7, M68pdCacheNotIO | M68pdCacheinhib           ; these should both end up set
    bc      BO_IF_NOT, bM68pdResident, vmRetNeg1
    beq     vmRet
    bc      BO_IF_NOT, cr4_lt, vmMakePageNonCacheableForIO  ; not a paged area, so for I/O

    bcl     BO_IF_NOT, bM68pdInHTAB, QuickCalcPTE

    rlwinm  r9, r9,  0, ~(LpteWritethru | LpteInhibcache)
    lwz     r7, KDP.PageAttributeInit(r1)
    rlwimi  r9, r7, 0, LpteMemcoher | LpteGuardwrite
    ori     r16, r16, M68pdCacheNotIO | M68pdCacheinhib
    ori     r9, r9, LpteInhibcache

    bl      SavePTEAnd68kPD
    ; Fall through to vmFlushPageAndReturn

########################################################################

vmFlushPageAndReturn ; When making page write-though or noncacheable
    rlwinm  r4, r9, 0, 0xFFFFF000
    addi    r5, r4, 32
    li      r7, 0x1000
    li      r8, 64
@loop
    subf.   r7, r8, r7
    dcbf    r7, r4
    dcbf    r7, r5
    bne     @loop
    b       vmRet

########################################################################

vmMakePageNonCacheableForIO
    rlwinm  r7, r4, 16, 0xF
    cmpwi   r7, kMinIOSegment
    blt     vmRetNeg1

    bc      BO_IF, bM68pdCacheinhib, vmRetNeg1  ; I/O space is always cache-inhibited

    lwz     r5, PMDT.Word2(r15)                 ; only if page unity mapped
    srwi    r6, r5, 12                          ; (i.e. logical = physical)
    cmpw    r6, r4
    bne     vmRetNeg1

    lis     r7, 0                               ; unclear significance
    lis     r8, 0
    lis     r9, 0

    srwi    r6, r5, 12
    lhz     r8, PMDT.PageCount(r15)
    lhz     r7, PMDT.PageIdx(r15)
    addi    r6, r6, 1

    cmpwi   r8, 0
    beq     @onepage

; many page ; preserve this PMDT but chop off its first page (this one)
    addi    r7, r7, 1
    subi    r8, r8, 1
    rlwimi  r5, r6, 12, 0xFFFFF000
    sth     r7, PMDT.PageIdx(r15)
    sth     r8, PMDT.PageCount(r15)
    stw     r5, PMDT.Word2(r15)
    b       vmCleanupTrashedPMDT

@onepage ; move the next PMDT leftwards to overwrite this slot
    lis     r6, 0
    lwz     r7, PMDT.Size + 0(r15)
    lwz     r8, PMDT.Size + 4(r15)
    lis     r5, 0
    ori     r6, r6, PMDT_Available
    stw     r7, 0(r15)
    stw     r8, 4(r15)
    stw     r5, PMDT.Size + 0(r15)
    stw     r6, PMDT.Size + 4(r15)

    dcbf    0, r15
    b       vmCleanupTrashedPMDT

########################################################################

VMMarkBacking ; page a0/r4, is_inited a1/r5
; Opposite of VMMarkResident
    bl      PageInfo
    bc      BO_IF_NOT, cr4_lt, vmRetNeg1    ; not a paged area
    bc      BO_IF, bM68pdGlobal, vmRetNeg1

    bcl     BO_IF, bM68pdInHTAB, DeletePTE

    _mvbit  r16, bM68pdInited, r5, 31
    li      r7, M68pdResident
    andc    r16, r16, r7
    stw     r16, 0(r15)

    b       vmRet

########################################################################

VMMarkCleanUnused ; page a0/r4
    bl      PageInfo
    bc      BO_IF_NOT, cr4_lt, vmRetNeg1    ; not a paged area
    bc      BO_IF_NOT, bM68pdResident, vmRetNeg1

    bcl     BO_IF_NOT, bM68pdInHTAB, QuickCalcPTE

    li      r7, LpteReference | LpteChange
    andc    r9, r9, r7
    ori     r16, r16, M68pdShouldClean
    bl      SavePTEAnd68kPD

    b       vmRet

########################################################################

VMMarkUndefined ; first_page a0/r4, page_count a1/r5
; Not too sure what this does
    cmplw   r4, r9
    cmplw   cr1, r5, r9
    add     r7, r4, r5
    cmplw   cr2, r7, r9
    bge     vmRetNeg1                           ; outside VM area!
    bgt     cr1, vmRetNeg1
    bgt     cr2, vmRetNeg1

    lwz     r15, KDP.VMPageArray(r1)
    slwi    r8, r7, 2
    li      r7, 1
@loop
    subi    r8, r8, 4
    subf.   r5, r7, r5
    lwzx    r16, r15, r8
    blt     vmRet
    _mvbit  r16, bM68pdSupProtect, r6, 31
    stwx    r16, r15, r8
    b       @loop

########################################################################

VMMarkResident ; page a0/r4, p_page a1/r5
; Opposite of VMMarkBacking
    bl      PageInfo
    bc      BO_IF_NOT, cr4_lt, vmRetNeg1        ; not a paged area!
    bc      BO_IF, bM68pdResident, vmRetNeg1    ; already resident!
    bcl     BO_IF, bM68pdInHTAB, CrashVirtualMem; corrupt 68k PD!

    rlwimi  r16, r5, 12, 0xFFFFF000             ; make up a 68k PD
    ori     r16, r16, M68pdResident             ; save it
    stw     r16, 0(r15)

    bl      QuickCalcPTE                        ; make up a PPC PTE
    bl      SavePTEAnd68kPD                     ; save it

    b       vmRet

########################################################################

VMPTest ; page a0/r4, action d1/r6 // reason d0/r3
; Return reason we got a page fault
    srwi    r4, r4, 12          ; because it was outside a paged area?
    cmplw   r4, r9
    li      r3, 1 << 14
    bge     vmRet

    bl      PageInfo            ; because the page was non-resident?
    li      r3, 1 << 10
    bc      BO_IF_NOT, bM68pdResident, vmRet

    li      r3, 0               ; unknown!
    ori     r3, r3, 1 << 15
    bc      BO_IF_NOT, bM68pdWriteProtect, vmRet
    cmpwi   r6, 0
    beq     vmRet

    li      r3, 1 << 11         ; because wrote to write-protected page
    b       vmRet               ; (requires d1/r6 to be non-zero)

########################################################################

VMSetPTEntryGivenPage ; 68kpte a0/r4, page a1/r5
; Set a page's 68k Page Descriptor (some bits cannot be set)
    mr      r6, r4
    mr      r4, r5
    bl      PageInfo
    bc      BO_IF_NOT, cr4_lt, vmRetNeg1    ; not a paged area

    xor     r7, r16, r6         ; r17 = bits to be changed

                                ; cannot change G/CM0/CM1/PTD0 with this call
    li      r3, M68pdGlobal | M68pdCacheinhib | M68pdCacheNotIO | M68pdResident
    _mvbit  r3, bM68pdWriteProtect, r16, bM68pdGlobal ; cannot change WP if G is set
    and.    r3, r3, r7
    bne     vmRetNeg1           ; fail if trying to change a forbidden bit

    andi.   r7, r7, M68pdShouldClean | M68pdModified | M68pdUsed | M68pdWriteProtect
    xor     r16, r16, r7        ; silently refuse to change U0/M/U/WP
    stw     r16, 0(r15)         ; save new 68k PD

    bc      BO_IF_NOT, bM68pdInHTAB, vmRet          ; edit PPC PTE if applicable
    _mvbit  r9, bLpteReference, r16, bM68pdUsed
    _mvbit  r9, bLpteChange, r16, bM68pdModified
    _mvbit  r9, bLpteP1, r16, bM68pdWriteProtect
    bl      SaveLowerPTE
    b       vmRet

########################################################################

VMShouldClean ; page a0/r4 // bool d0/r3
; Is this page is a good candidate for writing to disk?
    bl      PageInfo
    bc      BO_IF_NOT, bM68pdResident, vmRet0   ; already paged out: no
    bc      BO_IF, bM68pdUsed, vmRet0           ; been read recently: no
    bc      BO_IF_NOT, bM68pdModified, vmRet0   ; unwritten ('clean'): no
    bc      BO_IF_NOT, cr4_lt, vmRetNeg1        ; not a paged area: error

    xori    r16, r16, M68pdModified             ; clear 68k-PD[M]
    ori     r16, r16, M68pdShouldClean          ; set user-defined bit
    stw     r16, 0(r15)

    bc      BO_IF_NOT, bM68pdInHTAB, vmRet1     ; clear PPC-PTE[C]
    xori    r9, r9, LpteChange                  ; (if necessary)
    bl      SaveLowerPTE
    b       vmRet1                              ; return yes!

########################################################################

VMAllocateMemory ; first_page a0/r4, page_count a1/r5, align_mask d1/r6
; Allocate and wire a logical area with the specified physical alignment.
; The physical RAM is acquired by *shrinking* the VM area (hopefully in early boot).
    lwz     r7, KDP.VMPageArray(r1)         ; Assert: r5 positive, VM off, r4 and r6 < 0x100000
    lwz     r8, KDP.PhysicalPageArray(r1)
    cmpwi   cr6, r5, 0
    cmpw    cr7, r7, r8
    or      r7, r4, r6
    rlwinm. r7, r7, 0, 0xFFF00000

; Prepare for PageInfo calls (r4 and r9!), saving the first_page arg in r7.
    ble     cr6, vmRetNeg1
    lwz     r9, KDP.VMLogicalPages(r1)
    bne     cr7, vmRetNeg1
    mr      r7, r4
    bne     vmRetNeg1
    mr      r4, r9

; Scan the VM area right->left until we have enough (aligned) physical RAM to steal.
    slwi    r6, r6, 12                      ; r6 = mask of bits that must be zero in phys base
    subi    r5, r5, 1                       ; r5 = page_count - 1
@pageloop
    subi    r4, r4, 1
    bl      PageInfo                            
    bcl     BO_IF, bM68pdInHTAB, DeletePTE  ; Naturally this RAM should be expunged from the HTAB

    lwz     r9, KDP.VMLogicalPages(r1)
    subf    r8, r4, r9
    cmplw   cr7, r5, r8
    and.    r8, r16, r6
    bge     cr7, @pageloop                  ; Don't yet have enough pages: next!
    bne     @pageloop                       ; This page is not aligned: next!

    cmpwi   cr6, r6, 0                      ; If no alignment is required then we can assume
    beq     cr6, @exitpageloop              ; that discontiguous RAM is okay. (cr6_eq = 1)

    slwi    r8, r5, 2
    lwzx    r8, r15, r8
    slwi    r14, r5, 12
    add     r14, r14, r16
    xor     r8, r8, r14
    rlwinm. r8, r8, 0, 0xFFFFF000
    bne     @pageloop                       ; Physical RAM discontiguous: next!
@exitpageloop ; cr6_eq = !(can be discontiguous)

; Fail if the requested area is in VM reserved segments, or sized > 4 GB
    lis     r9, kMaxVirtualSegments
    cmplw   cr7, r7, r9
    rlwinm. r9, r7, 0, 0xFFF00000
    blt     cr7, vmRetNeg1
    bne     vmRetNeg1

; Find the PMDT containing the new area.
    lwz     r14, KDP.CurSpace.SegMapPtr(r1)
    rlwinm  r9, r7, 19, 25, 28
    lwzx    r14, r14, r9
    clrlwi  r9, r7, 16
    lhz     r8, PMDT.PageIdx(r14)
    b       @enterpmdtloop
@pmdtloop
    lhzu    r8, PMDT.Size + PMDT.PageIdx(r14)
@enterpmdtloop
    lhz     r16, PMDT.PageCount(r14)
    subf    r8, r8, r9
    cmplw   cr7, r8, r16
    bgt     cr7, @pmdtloop
    add     r8, r8, r5                      ; if PMDT does not fully enclose the area, fail!
    cmplw   cr7, r8, r16
    bgt     cr7, vmRetNeg1

; That PMDT had better be Available, because we're replacing it with one for our area.
    lwz     r16, PMDT.Word2(r14)
    slwi    r8, r7, 16
    andi.   r16, r16, EveryPattr
    cmpwi   r16, PMDT_Available
    or      r8, r8, r5
    addi    r5, r5, 1
    bne     vmRetNeg1
    stw     r8, 0(r14) ; PMDT.PageIdx/PageCount
    bnel    cr6, ReclaimLeftoverFromVMAlloc ; Move our area to the very end of VMPageArray
    rotlwi  r15, r15, 10
    ori     r15, r15, PMDT_Paged
    stw     r15, PMDT.Word2(r14)

; Disappear the RAM we stole. We've always been at war with Eastasia.
    lwz     r7, KDP.VMPhysicalPages(r1)
    subf    r7, r5, r7
    stw     r7, KDP.VMPhysicalPages(r1)
    stw     r7, KDP.VMLogicalPages(r1)
    slwi    r8, r7, 12
    stw     r8, KDP.SysInfo.UsableMemorySize(r1)
    stw     r8, KDP.SysInfo.LogicalMemorySize(r1)

; Because we rearranged the VMPageArray, rewrite the VM area PMDTs
    addi    r14, r1, KDP.SegMaps-8
    lwz     r15, KDP.VMPageArray(r1)
    li      r8, 0                           ; r8 = upper PMDT denoting whole-segment
    subi    r7, r7, 1
    ori     r8, r8, 0xffff
@nextseg
    cmplwi  r7, 0xffff
    lwzu    r16, 8(r14)
    rotlwi  r9, r15, 10
    ori     r9, r9, PMDT_Paged
    stw     r8, 0(r16)                      ; PMDT.PageIdx/PageCount = whole segment
    stw     r9, PMDT.Word2(r16)
    addis   r15, r15, 4
    subis   r7, r7, 1
    bgt     @nextseg
    sth     r7, PMDT.PageCount(r16)         ; (last segment is partial)

    b       vmRet1

ReclaimLeftoverFromVMAlloc ; 68kpds_to_steal r15 // 68kpds_to_steal r15
; We had to steal extra pages to ensure physically aligned backing. Return
; the "tail" pages that we won't use to the "body" of the VM area. Do this
; by exchanging the stolen 68k-PDs for the tail ones, then changing r15.
    lwz     r16, 0(r15)                     ; r16 = first stolen 68k-PD

    lwz     r7, KDP.VMPhysicalPages(r1)     ; r7 = where to move stolen 68k-PDs
    lwz     r8, KDP.VMPageArray(r1)         ; r8 = last 68k-PD to overwrite
    slwi    r7, r7, 2
    add     r7, r7, r8
    slwi    r8, r5, 2
    subf    r7, r8, r7

    cmplw   r15, r7                         ; Return early if there is no tail.
    beqlr

    subi    r7, r7, 4                       ; Carefully move "tail" 68k-PDs down
@tailmoveloop                               ; to the end of the VM area "body"
    lwzx    r9, r15, r8
    cmplw   r15, r7
    stw     r9, 0(r15)
    addi    r15, r15, 4
    blt     @tailmoveloop

@stolenfillloop                             ; Then carelessly reconstitute the
    cmpwi   r8, 4                           ; stolen 68k-PDs that we just over-
    subi    r8, r8, 4                       ; wrote. We can be careless because
    stwu    r16, 4(r7)                      ; we know that the physical pages
    addi    r16, r16, 0x1000                ; are contiguous.
    bgt     @stolenfillloop
    blr     

########################################################################

; Given the index of a page (a0/r4), this function scrapes together most
; of the information available. For a page within a paged area (i.e.
; PMDT_Paged) the 68k Page Descriptor (PD) is returned, as well as the
; PowerPC Page Table Entry (PTE) if one currently exists in the HTAB. For
; pages in a non-paged area, a fake 68k PD is constructed, and a pointer
; to the relevant PMDT is also returned. In both cases, 68k PD attribute
; bits are placed in the condition registers for easy testing.
; VMLogicalPages must be passed in r9 (as set by VMDispatch).

; Returns:     cr4_lt         =  1
; (paged area) r16/r15/cr5-7  =  68k Page Descriptor [PD/pointer/attr-bits]
;              r8/r9/r14      =  PowerPC Page Table Entry [PTE-high/PTE-low/pointer]

; Returns:     cr4_lt         =  0
; (not paged)  r16/cr5-7      =  fake 68k Page Descriptor [PD/attr-bits]
;              r15            =  PMDT pointer

PageInfo
    cmplw   cr4, r4, r9
    lwz     r15, KDP.VMPageArray(r1)        ; r15 = 68k Page Descriptor array base
    slwi    r8, r4, 2                       ; r18 = 68k Page Descriptor array offset
    bge     cr4, @outside_vm_area

@paged ; (cr4_lt is always set when we get here)
    lwzux   r16, r15, r8                    ; Get 68k Page Descriptor (itself to r16, ptr to r15)
    lwz     r14, KDP.HTABORG(r1)
    mtcrf   %00000111, r16                  ; Set all attrib bits in CR
    rlwinm  r8, r16, 23, 0x007FFFF8         ; r8 = Page Table Entry offset
    rlwinm  r9, r16, 0, 0xFFFFF000          ; failing a real PTE, this will do do

    bclr    BO_IF_NOT, bM68pdInHTAB         ; No PTE? Fine, we have enough info.
    bc      BO_IF_NOT, bM68pdResident, CrashVirtualMem  ; PD corrupt!
    lwzux   r8, r14, r8                     ; Get PTE in r8/r9 (the usual registers for this file)
    lwz     r9, 4(r14)
    mtcrf   %10000000, r8                   ; set CR bit 0 to Valid bit
    _mvbit  r16, bM68pdModified, r9, bLpteChange        ; take this change to update 68k PD
    _mvbit  r16, bM68pdUsed, r9, bLpteReference         ; with info from PPC "touch" bits
    mtcrf   %00000111, r16
    bclr    BO_IF, bUpteValid               ; Return
    bl      CrashVirtualMem                 ; (But crash if PTE is invalid)

@outside_vm_area ; Code outside VM Manager address space
    lis     r9, kMaxVirtualSegments         ; Check that page is outside VM Manager's segments
    cmplw   cr4, r4, r9                     ; but still a valid page number (i.e. < 0x100000)
    rlwinm. r9, r4, 0, 0xFFF00000
    blt     cr4, vmRetNeg1                  ; (else return -1 from VM call)
    bne     vmRetNeg1

    lwz     r15, KDP.CurSpace.SegMapPtr(r1) ; r15 = Segment Map base
    rlwinm  r9, r4, 19, 25, 28              ; r9 = offset into Segment Map = segment number * 8
    lwzx    r15, r15, r9                    ; Ignore Seg flags, get pointer into Page Map
    clrlwi  r9, r4, 16                      ; r9 = index of this page within its Segment

    lhz     r8, PMDT.PageIdx(r15)           ; Search the PageMap for the right PMDT...
    b       @pmloop_enter
@pmloop
    lhzu    r8, PMDT.Size(r15)              ; (PMDT.PageIdx of next entry)
@pmloop_enter
    lhz     r16, PMDT.PageCount(r15)
    subf    r8, r8, r9
    cmplw   cr4, r8, r16
    bgt     cr4, @pmloop

    lwz     r9, PMDT.Word2(r15)
    andi.   r16, r9, Pattr_NotPTE | Pattr_PTE_Single
    cmpwi   cr6, r16, PMDT_PTE_Single
    cmpwi   cr7, r16, PMDT_Paged
    beq     @range_pmdt
    beq     cr6, @single_pmdt
    bne     cr7, vmRetNeg1

; paged pmdt
    slwi    r8, r8, 2                       ; r8 = offset of 68k PD within segment's array
    rlwinm  r15, r9, 22, 0xFFFFFFFC         ; r15 = ptr to segment's PD array (r8 and r15 to be lwzux'd)
    crset   cr4_lt                          ; return "is paged"
    b       @paged                          ; back to main code path above

@range_pmdt                                 ; But if not a paged area, still return some info
    slwi    r8, r8, 12
    add     r9, r9, r8
@single_pmdt
    rlwinm  r16, r9, 0, 0xFFFFF000          ; fabricate a 68k Page Descriptor
    crclr   cr4_lt                          ; return "is not paged"
    rlwinm  r9, r9,  0, ~PMDT_Paged
    _mvbit  r16, bM68pdCacheinhib, r9, bLpteInhibcache
    _mvbit  r16, bM68pdCacheNotIO, r9, bLpteWritethru
    xori    r16, r16, M68pdCacheNotIO
    _mvbit  r16, bM68pdModified, r9, bLpteChange
    _mvbit  r16, bM68pdUsed, r9, bLpteChange
    _mvbit  r16, bM68pdWriteProtect, r9, bLpteP1
    ori     r16, r16, M68pdResident

    mtcrf   %00000111, r16                  ; extract flags and return
    blr     

########################################################################

SavePTEAnd68kPD
    stw     r16, 0(r15)     ; save r16 (PD) into r15 (PD ptr)
SavePTE
    stw     r8, 0(r14)      ; save r8 (upper PTE) into r14 (PTE ptr)
SaveLowerPTE
    stw     r9, 4(r14)      ; save r9 (lower PTE) into r14 (PTE ptr) + 4

    slwi    r8, r4, 12      ; trash TLB
    sync
    tlbie   r8
    sync    

    blr

########################################################################

DeletePTE
    lwz     r8, KDP.NKInfo.HashTableDeleteCount(r1)
    rlwinm  r16, r16, 0, ~M68pdInHTAB
    addi    r8, r8, 1
    stw     r8, KDP.NKInfo.HashTableDeleteCount(r1)
    rlwimi  r16, r9, 0, 0xFFFFF000      ; edit new 68k PD

    _clrNCBCache scr=r8                 ; page can now move, so clr NCBs

    li      r8, 0                       ; zero new PPC PTE
    li      r9, 0

    b       SavePTEAnd68kPD

########################################################################

; Calculate a new PowerPC PTE for a page that is not currently in the
; HTAB. The new PTE (and new ptr) will be in the usual r8/r9 and r14, and
; the new 68k PD (and unchanged ptr) will be in the usual r16 and r15.
; Because it tries a quick path but falls back on the big fat PutPTE, this
; function may or may not actually put the PowerPC and 68k structures into
; place. The caller must do this.

QuickCalcPTE
    lwz     r8, KDP.PTEGMask(r1)        ; Calculate hash to find PTEG
    lwz     r14, KDP.HTABORG(r1)
    slwi    r9, r4, 12
    mfsrin  r6, r9
    xor     r9, r6, r4
    slwi    r7, r9, 6
    and     r8, r8, r7

    lwzux   r7, r14, r8                 ; Find an invalid PTE in the right PTEG...
    lwz     r8, 8(r14)
    lwz     r9, 16(r14)
    lwz     r5, 24(r14)
    cmpwi   cr0, r7, 0
    cmpwi   cr1, r8, 0
    cmpwi   cr2, r9, 0
    cmpwi   cr3, r5, 0
    bge     cr0, @pte_at_r14
    bge     cr1, @pte_at_r14_plus_8
    bge     cr2, @pte_at_r14_plus_16
    bge     cr3, @pte_at_r14_plus_24
    lwzu    r7, 32(r14)
    lwz     r8, 8(r14)
    lwz     r9, 16(r14)
    lwz     r5, 24(r14)
    cmpwi   cr0, r7, 0
    cmpwi   cr1, r8, 0
    cmpwi   cr2, r9, 0
    cmpwi   cr3, r5, 0
    bge     cr0, @pte_at_r14
    bge     cr1, @pte_at_r14_plus_8
    bge     cr2, @pte_at_r14_plus_16
    blt     cr3, @heavyweight           ; (no free slot, so use PutPTE and rerun PageInfo)
@pte_at_r14_plus_24
    addi    r14, r14, 8
@pte_at_r14_plus_16
    addi    r14, r14, 8
@pte_at_r14_plus_8
    addi    r14, r14, 8
@pte_at_r14                             ; ... and put a pointer in r14.

; Quick path: there is a PTE slot that the caller can fill
    lwz     r9, KDP.NKInfo.HashTableCreateCount(r1)
    rlwinm  r8, r6,  7, UpteVSID            ; r8 will be new upper PTE
    addi    r9, r9, 1
    stw     r9, KDP.NKInfo.HashTableCreateCount(r1)
    rlwimi  r8, r4, 22, UpteAPI
    lwz     r9, KDP.PageAttributeInit(r1)   ; r9 will be new lower PTE
    _ori    r8, r8, UpteValid
    rlwimi  r9, r16, 0, 0xFFFFF000
    _mvbit  r9, bLpteReference, r16, bM68pdUsed
    _mvbit  r9, bLpteChange, r16, bM68pdModified
    _mvbit  r9, bLpteInhibcache, r16, bM68pdCacheinhib
    _mvbit  r9, bLpteWritethru, r16, bM68pdCacheNotIO
    xori    r9, r9, M68pdCacheinhib
    _mvbit  r9, bLpteP1, r16, bM68pdWriteProtect

    lwz     r7, KDP.HTABORG(r1)
    ori     r16, r16, M68pdInHTAB | M68pdResident
    subf    r7, r7, r14
    rlwimi  r16, r7, 9, 0xFFFFF000      ; put PTE ptr info into 68k PD
    blr     

@heavyweight ; Slow path: the full PutPTE, with all its weird registers!
    mr      r7, r27
    mr      r8, r29
    mr      r9, r30
    mr      r5, r31
    mr      r16, r28
    mr      r14, r26
    mflr    r6
    slwi    r27, r4, 12
    bl      PutPTE
    bnel    CrashVirtualMem
    mr      r27, r7
    mr      r29, r8
    mr      r30, r9
    mr      r31, r5
    mr      r28, r16
    mr      r26, r14
    mtlr    r6

    lwz     r9, KDP.VMLogicalPages(r1)
    b       PageInfo                    ; <= r4

########################################################################

; Assumes that the page numbered r7 is within the paged area, resident,
; and not in the HTAB. Returns a physical pointer in r9.

vmInitGetPhysical
    addi    r8, r1, KDP.PhysicalPageArray
    lwz     r9, KDP.VMPhysicalPages(r1)
    rlwimi  r8, r7, 18, 28, 29
    cmplw   r7, r9
    lwz     r8, 0(r8)
    rlwinm  r7, r7, 2, 0xFFFF * 4
    bge     vmRetNeg1
    lwzx    r9, r8, r7              ; r9 = 68k PD
    rlwinm  r9, r9, 0, 0xFFFFF000   ; r9 = physical address to return
    blr     
