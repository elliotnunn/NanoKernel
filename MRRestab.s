; Lookup table when resuming MemRetry after an MRException has been handled

    MACRO
    restabLine &myFlags, &secLabel
    DC.B &myFlags
    DC.B (&secLabel-MRBase) >> 2
    ENDM

MRRestab
MRResLBZux       restabLine  %0001, MRSecLoad        ;  0 ; LBZ(U)(X)
MRResLHZux       restabLine  %0001, MRSecLoad        ;  1 ; LHZ(U)(X)
MRResLWZux       restabLine  %0001, MRSecLoad        ;  2 ; LWZ(U)(X)
MRResLDux        restabLine  %0001, MRSecLoad        ;  3 ; LD(U)X + X-788 + X-820

                 restabLine  %0001, MRSecException   ;  4
MRResLHAux       restabLine  %0001, MRSecLoadExt     ;  5 ; LHA(U)(X)
MRResLWAux       restabLine  %0001, MRSecLoad        ;  6 ; LWA(U)X
                 restabLine  %0001, MRSecException   ;  7

                 restabLine  %0001, MRSecException   ;  8
MRResLHBRX       restabLine  %0011, MRSecLHBRX       ;  9 ; LHBRX
MRResLWBRX       restabLine  %0011, MRSecLWBRX       ; 10 ; LWBRX
                 restabLine  %0001, MRSecException   ; 11

                 restabLine  %0001, MRSecException   ; 12
                 restabLine  %0001, MRSecException   ; 13
MRResLFSux       restabLine  %0001, MRSecLFSu        ; 14 ; LFS(U)(X)
MRResLFDux       restabLine  %0001, MRSecLFDu        ; 15 ; LFD(U)(X)

MRResST1ux       restabLine  %0001, MRSecDone        ; 16 ; STB(U)(X)
MRResST2ux       restabLine  %0001, MRSecDone        ; 17 ; STH(U)(X) + STHBRX
MRResST4ux       restabLine  %0001, MRSecDone        ; 18 ; STW(U)(X) + STFS(U)(X) + STWBRX + STFIWX
MRResST8ux       restabLine  %0001, MRSecDone        ; 19 ; STFD(U)(X) + STDUX

MRResLWARX       restabLine  %0001, MRSecLWARX       ; 20 ; LWARX
MRResLDARX       restabLine  %0001, MRSecException   ; 21 ; LDARX
MRResSTWCX       restabLine  %0001, MRSecSTWCX       ; 22 ; STWCX.
MRResSTDCX       restabLine  %0001, MRSecException   ; 23 ; STDCX.

                 restabLine  %0001, MRSecException   ; 24
                 restabLine  %0001, MRSecException   ; 25
MRResLMW         restabLine  %0011, MRSecLMW         ; 26 ; LMW
MRResX884        restabLine  %0011, MRSecException   ; 27 ; X-884

                 restabLine  %0001, MRSecException   ; 28
                 restabLine  %0001, MRSecException   ; 29
MRResSTMW        restabLine  %0011, MRSecSTMW        ; 30 ; STMW
MRResX1012       restabLine  %0011, MRSecException   ; 31 ; -1012

MRResLSWix       restabLine  %0011, MRSecLSWix       ; 32 ; LSW(I|X)
                 restabLine  %0011, MRSecLSWix       ; 33
                 restabLine  %0011, MRSecLSWix       ; 34
                 restabLine  %0011, MRSecLSWix       ; 35

MRResSTSWix      restabLine  %0011, MRSecStrStore    ; 36 ; STSW(I|X)
                 restabLine  %0011, MRSecStrStore    ; 37
                 restabLine  %0011, MRSecStrStore    ; 38
                 restabLine  %0011, MRSecStrStore    ; 39

MRResLSCBX       restabLine  %0011, MRSecLSCBX       ; 40 ; LSCBX
                 restabLine  %0011, MRSecLSCBX       ; 41
                 restabLine  %0011, MRSecLSCBX       ; 42
                 restabLine  %0011, MRSecLSCBX       ; 43
                 restabLine  %0011, MRSecLSCBX       ; 44
                 restabLine  %0011, MRSecLSCBX       ; 45
                 restabLine  %0011, MRSecLSCBX       ; 46
                 restabLine  %0011, MRSecLSCBX       ; 47

MRResDCBZ        restabLine  %0011, MRSecDCBZ        ; 48 ; DCBZ
                 restabLine  %0001, MRSecException   ; 49
                 restabLine  %0001, MRSecException   ; 50
                 restabLine  %0001, MRSecException   ; 51

                 restabLine  %0001, MRSecException   ; 52 ; A little birdie told me these will change in later versions
                 restabLine  %0001, MRSecException   ; 53
                 restabLine  %0001, MRSecException   ; 54
                 restabLine  %0001, MRSecException   ; 55
                 restabLine  %0001, MRSecException   ; 56
                 restabLine  %0001, MRSecException   ; 57
                 restabLine  %0001, MRSecException   ; 58
                 restabLine  %0001, MRSecException   ; 59

                 restabLine  %0001, MRSecException   ; 60
                 restabLine  %0001, MRSecException   ; 61
MRResRedoNoTrace restabLine  %0011, MRSecRedoNoTrace ; 62 ; DCBT + ICBI + DCBST + DCBTST + X-86
MRResBlank       restabLine  %0001, MRSecException2  ; 63
