; MemRetry (data access emulator) entry point

; The interrupt handler that calls one of the "primary" routines
; should store all userspace registers in the EWA and set these:
;   r14 = saved MSR
;   r14 = saved MSR + MSR[DR]
;   r16 = flags
;   r17 = MR status (0-5 MRRestab entry || 6-10 src/dest register || 11-15 base register || 21-25 ?? || 26-30 access len || 31 0=Store/1=Load)
;   r18 = EA being accessed
;   r24 = saved VecBase
;   r25 = MRCode pointer (lower 10 bits can be "dirty")
;   r26 = MROptab entry (sec routine ptr in low 8 bits might be set on DSI)
;   r27 = instruction (optional if mrSkipInstLoad is set below)
;   r28 = offset of register field in EWA (= reg num * 4)

    MACRO
    optabRow &myAccLen, &myLoadStore, &resLabel, &myFlags, &primLabel, &secLabel
_L set 1
_S set 0
    DC.W (&myAccLen << 11) | (&myLoadStore << 10) | (((&resLabel - MRResTab) >> 1) << 4) | &myFlags
    DC.B (&primLabel-MRBase) >> 2
    DC.B (&secLabel-MRBase) >> 2
    ENDM

; LEGEND       .... access size (r17 bits 27-30) and 0=Store/1=Load (r17 bit 31)
;                     ................ MRRestab entry (r17 bits 0-5)
;
;                                        . mrSkipInstLoad       }
;                                         . mrXformIgnoreIdxReg } cr3 flags
;                                          . mrSuppressUpdate   }
;                                           . mrChangedRegInEWA }
;
;                                               primary routine   secondary routine  X-form extended opcode   D-form opcode
;                                               ................  ................   .......................  .................

    MACRO
    optabNone
    optabRow   0,_L,  MRResBlank,       %0000,  MRPriCrash,       MRSecException   ; defaults for blank rows
    ENDM

MROptabX
    optabRow   4,_L,  MRResLWARX,       %0000,  MRPriPlainLoad,   MRSecLWARX       ; 00000(101)00=020=LWARX
    optabRow   8,_L,  MRResLDARX,       %0000,  MRPriCrash,       MRSecException   ; 00010(101)00=084=LDARX
    optabNone                                                                      ; 00100(101)00=148
    optabNone                                                                      ; 00110(101)00=212
    optabNone                                                                      ; 01000(101)00=276
    optabNone                                                                      ; 01010(101)00=340
    optabNone                                                                      ; 01100(101)00=404
    optabNone                                                                      ; 01110(101)00=468
    optabNone                                                                      ; 10000(101)00=532
    optabNone                                                                      ; 10010(101)00=596
    optabNone                                                                      ; 10100(101)00=660
    optabNone                                                                      ; 10110(101)00=724
    optabRow   8,_L,  MRResLDux,        %0000,  MRPriPlainLoad,   MRSecLoad        ; 11000(101)00=788
    optabRow   4,_L,  MRResLWAux,       %0000,  MRPriPlainLoad,   MRSecLoad        ; 11010(101)00=852
    optabRow   8,_S,  MRResST8ux,       %0000,  MRPriPlainStore,  MRSecDone        ; 11100(101)00=916
    optabNone                                                                      ; 11110(101)00=980
    optabNone                                                                      ; 00001(101)00=052
    optabNone                                                                      ; 00011(101)00=116
    optabNone                                                                      ; 00101(101)00=180
    optabNone                                                                      ; 00111(101)00=244
    optabNone                                                                      ; 01001(101)00=308
    optabNone                                                                      ; 01011(101)00=372
    optabNone                                                                      ; 01101(101)00=436
    optabNone                                                                      ; 01111(101)00=500
    optabNone                                                                      ; 10001(101)00=564
    optabNone                                                                      ; 10011(101)00=628
    optabNone                                                                      ; 10101(101)00=692
    optabNone                                                                      ; 10111(101)00=756
    optabRow   8,_L,  MRResLDux,        %0000,  MRPriUpdLoad,     MRSecLoad        ; 11001(101)00=820
    optabRow   8,_L,  MRResX884,        %0011,  MRPriCrash,       MRSecException   ; 11011(101)00=884
    optabRow   8,_S,  MRResST8ux,       %0000,  MRPriUpdStore,    MRSecDone        ; 11101(101)00=948
    optabRow   8,_S,  MRResX1012,       %0010,  MRPriCrash,       MRSecException   ; 11111(101)00=1012
    optabRow   8,_L,  MRResLDux,        %0000,  MRPriPlainLoad,   MRSecLoad        ; 00000(101)01=021=LDX
    optabNone                                                                      ; 00010(101)01=085
    optabRow   8,_S,  MRResST8ux,       %0000,  MRPriPlainStore,  MRSecDone        ; 00100(101)01=149=STDX
    optabNone                                                                      ; 00110(101)01=213
    optabRow   4,_L,  MRResLSCBX,       %1011,  MRPriLSCBX,       MRSecLSCBX       ; 01000(101)01=277=LSCBX (POWER)
    optabRow   4,_L,  MRResLWAux,       %0000,  MRPriPlainLoad,   MRSecLoad        ; 01010(101)01=341=LWAX
    optabNone                                                                      ; 01100(101)01=405
    optabNone                                                                      ; 01110(101)01=469
    optabRow   4,_L,  MRResLSWix,       %1011,  MRPriLSWX,        MRSecLSWix       ; 10000(101)01=533=LSWX
    optabRow   4,_L,  MRResLSWix,       %1111,  MRPriLSWI,        MRSecLSWix       ; 10010(101)01=597=LSWI
    optabRow   4,_S,  MRResSTSWix,      %0010,  MRPriSTSWX,       MRSecStrStore    ; 10100(101)01=661=STSWX
    optabRow   4,_S,  MRResSTSWix,      %1110,  MRPriSTSWI,       MRSecStrStore    ; 10110(101)01=725=STSWI
    optabNone                                                                      ; 11000(101)01=789
    optabNone                                                                      ; 11010(101)01=853
    optabNone                                                                      ; 11100(101)01=917
    optabNone                                                                      ; 11110(101)01=981
    optabRow   8,_L,  MRResLDux,        %0000,  MRPriUpdLoad,     MRSecLoad        ; 00001(101)01=053=LDUX
    optabNone                                                                      ; 00011(101)01=117
    optabRow   8,_S,  MRResST8ux,       %0000,  MRPriUpdStore,    MRSecDone        ; 00101(101)01=181=STDUX
    optabNone                                                                      ; 00111(101)01=245
    optabNone                                                                      ; 01001(101)01=309
    optabRow   4,_L,  MRResLWAux,       %0000,  MRPriUpdLoad,     MRSecDone        ; 01011(101)01=373=LWAUX
    optabNone                                                                      ; 01101(101)01=437
    optabNone                                                                      ; 01111(101)01=501
    optabNone                                                                      ; 10001(101)01=565
    optabNone                                                                      ; 10011(101)01=629
    optabNone                                                                      ; 10101(101)01=693
    optabNone                                                                      ; 10111(101)01=757
    optabNone                                                                      ; 11001(101)01=821
    optabNone                                                                      ; 11011(101)01=885
    optabNone                                                                      ; 11101(101)01=949
    optabNone                                                                      ; 11111(101)01=1013
    optabNone                                                                      ; 00000(101)10=022
    optabRow   1,_L,  MRResRedoNoTrace, %0010,  MRPriUpdLoad,     MRSecRedoNoTrace ; 00010(101)10=086
    optabRow   4,_L,  MRResSTWCX,       %0000,  MRPriPlainStore,  MRSecSTWCX       ; 00100(101)10=150=STWCX.
    optabRow   8,_S,  MRResSTDCX,       %0000,  MRPriCrash,       MRSecException   ; 00110(101)10=214=STDCX.
    optabRow   1,_L,  MRResRedoNoTrace, %0010,  MRPriUpdLoad,     MRSecRedoNoTrace ; 01000(101)10=278=DCBT
    optabNone                                                                      ; 01010(101)10=342
    optabNone                                                                      ; 01100(101)10=406
    optabNone                                                                      ; 01110(101)10=470
    optabRow   4,_L,  MRResLWBRX,       %0010,  MRPriUpdLoad,     MRSecLWBRX       ; 10000(101)10=534=LWBRX
    optabNone                                                                      ; 10010(101)10=598
    optabRow   4,_S,  MRResST4ux,       %0000,  MRPriSTWBRX,      MRSecDone        ; 10100(101)10=662=STWBRX
    optabNone                                                                      ; 10110(101)10=726
    optabRow   2,_L,  MRResLHBRX,       %0010,  MRPriUpdLoad,     MRSecLHBRX       ; 11000(101)10=790=LHBRX
    optabNone                                                                      ; 11010(101)10=854
    optabRow   2,_S,  MRResST2ux,       %0000,  MRPriSTHBRX,      MRSecDone        ; 11100(101)10=918=STHBRX
    optabRow   1,_L,  MRResRedoNoTrace, %0010,  MRPriUpdLoad,     MRSecRedoNoTrace ; 11110(101)10=982=ICBI
    optabRow   1,_L,  MRResRedoNoTrace, %0010,  MRPriUpdLoad,     MRSecRedoNoTrace ; 00001(101)10=054=DCBST
    optabNone                                                                      ; 00011(101)10=118
    optabNone                                                                      ; 00101(101)10=182
    optabRow   1,_L,  MRResRedoNoTrace, %0010,  MRPriUpdLoad,     MRSecRedoNoTrace ; 00111(101)10=246=DCBTST
    optabRow   0,_L,  MRResBlank,       %0000,  MRPriPlainLoad,   MRSecException2  ; 01001(101)10=310=ECIWX
    optabNone                                                                      ; 01011(101)10=374
    optabRow   0,_S,  MRResBlank,       %0000,  MRPriPlainStore,  MRSecException2  ; 01101(101)10=438=ECOWX
    optabNone                                                                      ; 01111(101)10=502
    optabNone                                                                      ; 10001(101)10=566
    optabNone                                                                      ; 10011(101)10=630
    optabNone                                                                      ; 10101(101)10=694
    optabNone                                                                      ; 10111(101)10=758
    optabNone                                                                      ; 11001(101)10=822
    optabNone                                                                      ; 11011(101)10=886
    optabNone                                                                      ; 11101(101)10=950
    optabRow   8,_S,  MRResDCBZ,        %0010,  MRPriDCBZ,        MRSecDCBZ        ; 11111(101)10=1014=DCBZ
MROptabD ; X-form opcodes ending with 0b11 correspond with D-form opcodes, so these tables can overlap
    optabRow   4,_L,  MRResLWZux,       %0000,  MRPriPlainLoad,   MRSecLoad        ; 00000(101)11=023=LWZX    (1)00000=32=LWZ
    optabRow   1,_L,  MRResLBZux,       %0000,  MRPriPlainLoad,   MRSecLoad        ; 00010(101)11=087=LBZX    (1)00010=34=LBZ
    optabRow   4,_S,  MRResST4ux,       %0000,  MRPriPlainStore,  MRSecDone        ; 00100(101)11=151=STWX    (1)00100=36=STW
    optabRow   1,_S,  MRResST1ux,       %0000,  MRPriPlainStore,  MRSecDone        ; 00110(101)11=215=STBX    (1)00110=38=STB
    optabRow   2,_L,  MRResLHZux,       %0000,  MRPriPlainLoad,   MRSecLoad        ; 01000(101)11=279=LHZX    (1)01000=40=LHZ
    optabRow   2,_L,  MRResLHAux,       %0000,  MRPriPlainLoad,   MRSecLoadExt     ; 01010(101)11=343=LHAX    (1)01010=42=LHA
    optabRow   2,_S,  MRResST2ux,       %0000,  MRPriPlainStore,  MRSecDone        ; 01100(101)11=407=STHX    (1)01100=44=STH
    optabRow   4,_L,  MRResLMW,         %0011,  MRPriUpdLoad,     MRSecLMW         ; 01110(101)11=471         (1)01110=46=LMW
    optabRow   4,_L,  MRResLFSux,       %0000,  MRPriPlainLoad,   MRSecLFSu        ; 10000(101)11=535=LFSX    (1)10000=48=LFS
    optabRow   8,_L,  MRResLFDux,       %0000,  MRPriPlainLoad,   MRSecLFDu        ; 10010(101)11=599=LFDX    (1)10010=50=LFD
    optabRow   4,_S,  MRResST4ux,       %0000,  MRPriSTFSx,       MRSecDone        ; 10100(101)11=663=STFSX   (1)10100=52=STFS
    optabRow   8,_S,  MRResST8ux,       %0000,  MRPriSTFDx,       MRSecDone        ; 10110(101)11=727=STFDX   (1)10110=54=STFD
    optabNone                                                                      ; 11000(101)11=791         (1)11000=56
    optabNone                                                                      ; 11010(101)11=855         (1)11010=58
    optabNone                                                                      ; 11100(101)11=919         (1)11100=60
    optabRow   4,_S,  MRResST4ux,       %0000,  MRPriSTFDx,       MRSecDone        ; 11110(101)11=983=STFIWX  (1)11110=62
    optabRow   4,_L,  MRResLWZux,       %0000,  MRPriUpdLoad,     MRSecLoad        ; 00001(101)11=055=LWZUX   (1)00001=33=LWZU
    optabRow   1,_L,  MRResLBZux,       %0000,  MRPriUpdLoad,     MRSecLoad        ; 00011(101)11=119=LBZUX   (1)00011=35=LBZU
    optabRow   4,_S,  MRResST4ux,       %0000,  MRPriUpdStore,    MRSecDone        ; 00101(101)11=183=STWUX   (1)00101=37=STWU
    optabRow   1,_S,  MRResST1ux,       %0000,  MRPriUpdStore,    MRSecDone        ; 00111(101)11=247=STBUX   (1)00111=39=STBU
    optabRow   2,_L,  MRResLHZux,       %0000,  MRPriUpdLoad,     MRSecLoad        ; 01001(101)11=311=LHZUX   (1)01001=41=LHZU
    optabRow   2,_L,  MRResLHAux,       %0000,  MRPriUpdLoad,     MRSecLoadExt     ; 01011(101)11=375=LHAUX   (1)01011=43=LHAU
    optabRow   2,_S,  MRResST2ux,       %0000,  MRPriUpdStore,    MRSecDone        ; 01101(101)11=439=STHUX   (1)01101=45=STHU
    optabRow   4,_S,  MRResSTMW,        %0010,  MRPriUpdStore,    MRSecSTMW        ; 01111(101)11=503         (1)01111=47=STMW
    optabRow   4,_L,  MRResLFSux,       %0000,  MRPriUpdLoad,     MRSecLFSu        ; 10001(101)11=567=LFSUX   (1)10001=49=LFSU
    optabRow   8,_L,  MRResLFDux,       %0000,  MRPriUpdLoad,     MRSecLFDu        ; 10011(101)11=631=LFDUX   (1)10011=51=LFDU
    optabRow   4,_S,  MRResST4ux,       %0000,  MRPriSTFSUx,      MRSecDone        ; 10101(101)11=695=STFSUX  (1)10101=53=STFSU
    optabRow   8,_S,  MRResST8ux,       %0000,  MRPriSTFDUx,      MRSecDone        ; 10111(101)11=759=STFDUX  (1)10111=55=STFDU
    optabNone                                                                      ; 11001(101)11=823         (1)11001=57
    optabNone                                                                      ; 11011(101)11=887         (1)11011=59
    optabNone                                                                      ; 11101(101)11=951         (1)11101=61
    optabNone                                                                      ; 11111(101)11=1015        (1)11111=63
