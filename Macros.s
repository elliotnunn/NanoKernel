    MACRO
    _bitequate &bitnum, &name ; _bitequate 16, MyLabel => MyLabel=0x00008000, bMyLabel=16
&name equ 1 << (31-&bitnum)
b&name equ &bitnum
    ENDM

########################################################################

    MACRO
    _align &arg ; Macro necessary because PPCAsm versions vary
my_align set 1 << (&arg)
my_mask set my_align - 1
my_offset set * - CodeBase
my_pad set (my_align - (my_offset & my_mask)) & my_mask
    IF my_pad
    dcb.l   my_pad>>2, 0x48000004
    ENDIF
    ENDM

########################################################################

    MACRO
    lisori  &reg, &val ; NK's preferred way to load 32-bit immediate
    lis     &reg, ((&val) >> 16) & 0xffff
    ori     &reg, &reg, (&val) & 0xffff
    ENDM

########################################################################

    MACRO
    _kaddr &rd, &rs, &label ; Get address of label given CodeBase reg
    addi    &rd, &rs, (&label-CodeBase)
    ENDM

########################################################################

    MACRO
    _ori &rd, &rs, &imm
    IF (&imm) & 0xFFFF0000 THEN
        oris&dot    &rd, &rs, ((&imm) >> 16) & 0xFFFF ; beware sign ext!
    ELSE
        ori&dot     &rd, &rs, &imm
    ENDIF
    ENDM

########################################################################

    MACRO
    _mvbit &rd, &bd, &rs, &bs
    rlwimi &rd, &rs, (32 + &bs - &bd) % 32, &bd, &bd
    ENDM

########################################################################

    MACRO
    _mvbit0 &rd, &bd, &rs, &bs
    rlwinm &rd, &rs, (32 + &bs - &bd) % 32, &bd, &bd
    ENDM

########################################################################

    MACRO
    _clrNCBCache &scr==r0
    li      &scr, -1
    stw     &scr, KDP.NCBCacheLA0(r1)
    stw     &scr, KDP.NCBCacheLA1(r1)
    stw     &scr, KDP.NCBCacheLA2(r1)
    stw     &scr, KDP.NCBCacheLA3(r1)
    ENDM
