; Indexing this table:
;  bits  0-23  MRBase
;  bits 24-26  number of bytes to access minus one
;  bit     27  one for load, zero for store
;  bits 28-30  bottom three bits of adjusted EA
;  bit     31  zero (entries are 2b)

; "adjusted EA": address of the byte immediately to the right of the "string"

; Interpreting this table:
;  Entries refer to routines in MRMemtabCode, all
;  of which eventually jump to MRDoSecondary.

########################################################################

    MACRO
    memtabRow &label
    DC.W (&label-MRBase) - (*-MRMemtab)
    ENDM

MRMemtab
    memtabRow  MRStore8         ; 8-byte stores
    memtabRow  MRStore1241      ; mod 1
    memtabRow  MRStore242       ; mod 2
    memtabRow  MRStore1421      ; mod 3
    memtabRow  MRStore44        ; mod 4
    memtabRow  MRStore1241      ; mod 5
    memtabRow  MRStore242       ; mod 6
    memtabRow  MRStore1421      ; mod 7
    memtabRow  MRLoad8          ; 8-byte loads
    memtabRow  MRLoad1241       ; mod 1
    memtabRow  MRLoad242        ; mod 2
    memtabRow  MRLoad1421       ; mod 3
    memtabRow  MRLoad44         ; mod 4
    memtabRow  MRLoad1241       ; mod 5
    memtabRow  MRLoad242        ; mod 6
    memtabRow  MRLoad1421       ; mod 7

    memtabRow  MRStore1         ; 1-byte stores
    memtabRow  MRStore1         ; mod 1
    memtabRow  MRStore1         ; mod 2
    memtabRow  MRStore1         ; mod 3
    memtabRow  MRStore1         ; mod 4
    memtabRow  MRStore1         ; mod 5
    memtabRow  MRStore1         ; mod 6
    memtabRow  MRStore1         ; mod 7
    memtabRow  MRLoad1          ; 1-byte loads
    memtabRow  MRLoad1          ; mod 1
    memtabRow  MRLoad1          ; mod 2
    memtabRow  MRLoad1          ; mod 3
    memtabRow  MRLoad1          ; mod 4
    memtabRow  MRLoad1          ; mod 5
    memtabRow  MRLoad1          ; mod 6
    memtabRow  MRLoad1          ; mod 7

    memtabRow  MRStore2         ; 2-byte stores
    memtabRow  MRStore11        ; mod 1
    memtabRow  MRStore2         ; mod 2
    memtabRow  MRStore11        ; mod 3
    memtabRow  MRStore2         ; mod 4
    memtabRow  MRStore11        ; mod 5
    memtabRow  MRStore2         ; mod 6
    memtabRow  MRStore11        ; mod 7
    memtabRow  MRLoad2          ; 2-byte loads
    memtabRow  MRLoad11         ; mod 1
    memtabRow  MRLoad2          ; mod 2
    memtabRow  MRLoad11         ; mod 3
    memtabRow  MRLoad2          ; mod 4
    memtabRow  MRLoad11         ; mod 5
    memtabRow  MRLoad2          ; mod 6
    memtabRow  MRLoad11         ; mod 7

    memtabRow  MRStore12        ; 3-byte stores
    memtabRow  MRStore21        ; mod 1
    memtabRow  MRStore12        ; mod 2
    memtabRow  MRStore21        ; mod 3
    memtabRow  MRStore12        ; mod 4
    memtabRow  MRStore21        ; mod 5
    memtabRow  MRStore12        ; mod 6
    memtabRow  MRStore21        ; mod 7
    memtabRow  MRLoad12         ; 3-byte loads
    memtabRow  MRLoad21         ; mod 1
    memtabRow  MRLoad12         ; mod 2
    memtabRow  MRLoad21         ; mod 3
    memtabRow  MRLoad12         ; mod 4
    memtabRow  MRLoad21         ; mod 5
    memtabRow  MRLoad12         ; mod 6
    memtabRow  MRLoad21         ; mod 7

    memtabRow  MRStore4         ; 4-byte stores
    memtabRow  MRStore121       ; mod 1
    memtabRow  MRStore22        ; mod 2
    memtabRow  MRStore121       ; mod 3
    memtabRow  MRStore4         ; mod 4
    memtabRow  MRStore121       ; mod 5
    memtabRow  MRStore22        ; mod 6
    memtabRow  MRStore121       ; mod 7
    memtabRow  MRLoad4          ; 4-byte loads
    memtabRow  MRLoad121        ; mod 1
    memtabRow  MRLoad22         ; mod 2
    memtabRow  MRLoad121        ; mod 3
    memtabRow  MRLoad4          ; mod 4
    memtabRow  MRLoad121        ; mod 5
    memtabRow  MRLoad22         ; mod 6
    memtabRow  MRLoad121        ; mod 7

    memtabRow  MRStore14        ; 5-byte stores
    memtabRow  MRStore41        ; mod 1
    memtabRow  MRStore122       ; mod 2
    memtabRow  MRStore221       ; mod 3
    memtabRow  MRStore14        ; mod 4
    memtabRow  MRStore41        ; mod 5
    memtabRow  MRStore122       ; mod 6
    memtabRow  MRStore221       ; mod 7
    memtabRow  MRLoad14         ; 5-byte loads
    memtabRow  MRLoad41         ; mod 1
    memtabRow  MRLoad122        ; mod 2
    memtabRow  MRLoad221        ; mod 3
    memtabRow  MRLoad14         ; mod 4
    memtabRow  MRLoad41         ; mod 5
    memtabRow  MRLoad122        ; mod 6
    memtabRow  MRLoad221        ; mod 7

    memtabRow  MRStore24        ; 6-byte stores
    memtabRow  MRStore141       ; mod 1
    memtabRow  MRStore42        ; mod 2
    memtabRow  MRStore1221      ; mod 3
    memtabRow  MRStore24        ; mod 4
    memtabRow  MRStore141       ; mod 5
    memtabRow  MRStore42        ; mod 6
    memtabRow  MRStore1221      ; mod 7
    memtabRow  MRLoad24         ; 6-byte loads
    memtabRow  MRLoad141        ; mod 1
    memtabRow  MRLoad42         ; mod 2
    memtabRow  MRLoad1221       ; mod 3
    memtabRow  MRLoad24         ; mod 4
    memtabRow  MRLoad141        ; mod 5
    memtabRow  MRLoad42         ; mod 6
    memtabRow  MRLoad1221       ; mod 7

    memtabRow  MRStore124       ; 7-byte stores
    memtabRow  MRStore241       ; mod 1
    memtabRow  MRStore142       ; mod 2
    memtabRow  MRStore421       ; mod 3
    memtabRow  MRStore124       ; mod 4
    memtabRow  MRStore241       ; mod 5
    memtabRow  MRStore142       ; mod 6
    memtabRow  MRStore421       ; mod 7
    memtabRow  MRLoad124        ; 7-byte loads
    memtabRow  MRLoad241        ; mod 1
    memtabRow  MRLoad142        ; mod 2
    memtabRow  MRLoad421        ; mod 3
    memtabRow  MRLoad124        ; mod 4
    memtabRow  MRLoad241        ; mod 5
    memtabRow  MRLoad142        ; mod 6
    memtabRow  MRLoad421        ; mod 7
