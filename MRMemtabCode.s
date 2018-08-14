; Each routine accepts:
;  r17 = MR status
;  r19 = address of byte to the right of the string to be loaded/saved
;  r23 as a scratch register
;  r20/r21 = right-justified data (stores only)

; Before jumping to MRDoSecondary or one of the MRFast paths, each routine sets:
;  r20/r21 = right-justified data (loads only)
;  r17 has len field decremented
;  r23 = junk, not to be trusted

########################################################################

MRLoad1241
    lbz     r23, -8(r19)
    subi    r17, r17, 2
    insrwi  r20, r23, 8, 0

MRLoad241
    lhz     r23, -7(r19)
    subi    r17, r17, 4
    insrwi  r20, r23, 16, 8
    b       MRLoad41

MRLoad141
    lbz     r23, -6(r19)
    subi    r17, r17, 2
    insrwi  r20, r23, 8, 16

MRLoad41
    lwz     r23, -5(r19)
    subi    r17, r17, 8
    inslwi  r20, r23, 8, 24
    insrwi  r21, r23, 24, 0
    b       MRLoad1

MRLoad1421
    lbz     r23, -8(r19)
    subi    r17, r17, 2
    insrwi  r20, r23, 8, 0

MRLoad421
    lwz     r23, -7(r19)
    subi    r17, r17, 8
    inslwi  r20, r23, 24, 8
    insrwi  r21, r23, 8, 0
    b       MRLoad21

MRLoad1221
    lbz     r23, -6(r19)
    subi    r17, r17, 2
    insrwi  r20, r23, 8, 16

MRLoad221
    lhz     r23, -5(r19)
    subi    r17, r17, 4
    rlwimi  r20, r23, 24, 24, 31
    insrwi  r21, r23, 8, 0
    b       MRLoad21

MRLoad121
    lbz     r23, -4(r19)
    subi    r17, r17, 2
    insrwi  r21, r23, 8, 0

MRLoad21
    lhz     r23, -3(r19)
    subi    r17, r17, 4
    insrwi  r21, r23, 16, 8
    b       MRLoad1

MRLoad11
    lbz     r23, -2(r19)
    subi    r17, r17, 2
    insrwi  r21, r23, 8, 16

MRLoad1
    lbz     r23, -1(r19)
    insrwi  r21, r23, 8, 24
    b       MRDoSecondary

MRLoad242
    lhz     r23, -8(r19)
    subi    r17, r17, 4
    insrwi  r20, r23, 16, 0
    b       MRLoad42

MRLoad142
    lbz     r23, -7(r19)
    subi    r17, r17, 2
    insrwi  r20, r23, 8, 8

MRLoad42
    lwz     r23, -6(r19)
    subi    r17, r17, 8
    inslwi  r20, r23, 16, 16
    insrwi  r21, r23, 16, 0
    b       MRLoad2

MRLoad122
    lbz     r23, -5(r19)
    subi    r17, r17, 2
    insrwi  r20, r23, 8, 24
    b       MRLoad22

MRLoad12
    lbz     r23, -3(r19)
    subi    r17, r17, 2
    insrwi  r21, r23, 8, 8
    b       MRLoad2

MRLoad44
    lwz     r20, -8(r19)
    subi    r17, r17, 8
    lwz     r21, -4(r19)
    b       MRDoSecondary

MRLoad124
    lbz     r23, -7(r19)
    subi    r17, r17, 2
    insrwi  r20, r23, 8, 8

MRLoad24
    lhz     r23, -6(r19)
    subi    r17, r17, 4
    insrwi  r20, r23, 16, 16
    lwz     r21, -4(r19)
    b       MRDoSecondary

MRLoad14
    lbz     r23, -5(r19)
    subi    r17, r17, 2
    insrwi  r20, r23, 8, 24
MRLoad4
    lwz     r21, -4(r19)
    b       MRDoSecondary

MRLoad8
    lwz     r20, -8(r19)
    lwz     r21, -4(r19)
    b       MRDoSecondary

########################################################################

MRStore1241
    srwi    r23, r20, 24
    stb     r23, -8(r19)
    subi    r17, r17, 2

MRStore241
    srwi    r23, r20, 8
    sth     r23, -7(r19)
    subi    r17, r17, 4
    b       MRStore41

MRStore141
    srwi    r23, r20, 8
    stb     r23, -6(r19)
    subi    r17, r17, 2

MRStore41
    srwi    r23, r21, 8
    insrwi  r23, r20, 8, 0
    stw     r23, -5(r19)
    subi    r17, r17, 8
    stb     r21, -1(r19)
    b       MRDoSecondary

MRStore1421
    srwi    r23, r20, 24
    stb     r23, -8(r19)
    subi    r17, r17, 2

MRStore421
    srwi    r23, r21, 24
    insrwi  r23, r20, 24, 0
    stw     r23, -7(r19)
    subi    r17, r17, 8
    b       MRStore21

MRStore1221
    srwi    r23, r20, 8
    stb     r23, -6(r19)
    subi    r17, r17, 2

MRStore221
    srwi    r23, r21, 24
    insrwi  r23, r20, 8, 16
    sth     r23, -5(r19)
    subi    r17, r17, 4
    b       MRStore21

MRStore121
    srwi    r23, r21, 24
    stb     r23, -4(r19)
    subi    r17, r17, 2

MRStore21
    srwi    r23, r21, 8
    sth     r23, -3(r19)
    subi    r17, r17, 4
    stb     r21, -1(r19)
    b       MRDoSecondary

MRStore11
    srwi    r23, r21, 8
    stb     r23, -2(r19)
    subi    r17, r17, 2

MRStore1
    stb     r21, -1(r19)
    b       MRDoSecondary

MRStore242
    srwi    r23, r20, 16
    sth     r23, -8(r19)
    subi    r17, r17, 4
    b       MRStore42

MRStore142
    srwi    r23, r20, 16
    stb     r23, -7(r19)
    subi    r17, r17, 2

MRStore42
    srwi    r23, r21, 16
    insrwi  r23, r20, 16, 0
    stw     r23, -6(r19)
    subi    r17, r17, 8
    sth     r21, -2(r19)
    b       MRDoSecondary

MRStore122
    stb     r20, -5(r19)
    subi    r17, r17, 2
    b       MRStore22

MRStore12
    srwi    r23, r21, 16
    stb     r23, -3(r19)
    subi    r17, r17, 2

MRStore2
    sth     r21, -2(r19)
    b       MRDoSecondary

MRStore44
    stw     r20, -8(r19)
    subi    r17, r17, 8
    stw     r21, -4(r19)
    b       MRDoSecondary

MRStore124
    srwi    r23, r20, 16
    stb     r23, -7(r19)
    subi    r17, r17, 2

MRStore24
    sth     r20, -6(r19)
    subi    r17, r17, 4
    stw     r21, -4(r19)
    b       MRDoSecondary

MRStore14
    stb     r20, -5(r19)
    subi    r17, r17, 2

MRStore4
    stw     r21, -4(r19)
    b       MRDoSecondary

MRStore8
    stw     r20, -8(r19)
    stw     r21, -4(r19)
    b       MRDoSecondary
