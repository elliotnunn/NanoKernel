;_______________________________________________________________________
;	Configuration Info Record
;	Used to pass Configuration information from the Boot Program to the
;	NanoKernel for data structure and address mapping initialization.
;_______________________________________________________________________

NKConfigurationInfo		record	0,increment
ROMByteCheckSums		ds.l	8			; 000 ; ROM Checksums - one word for each of 8 byte lanes
ROMCheckSum64			ds.l	2			; 020 ; ROM Checksum - 64 bit sum of doublewords

ROMImageBaseOffset		ds.l	1			; 028 ; Offset of Base of total ROM image
ROMImageSize			ds.l	1			; 02c ; Number of bytes in ROM image
ROMImageVersion			ds.l	1			; 030 ; ROM Version number for entire ROM

Mac68KROMOffset			ds.l	1			; 034 ; Offset of base of Macintosh 68K ROM
Mac68KROMSize			ds.l	1			; 038 ; Number of bytes in Macintosh 68K ROM
	
ExceptionTableOffset	ds.l	1			; 03c ; Offset of base of PowerPC Exception Table Code
ExceptionTableSize		ds.l	1			; 040 ; Number of bytes in PowerPC Exception Table Code

HWInitCodeOffset		ds.l	1			; 044 ; Offset of base of Hardware Init Code (field moved!)
HWInitCodeSize			ds.l	1			; 048 ; Number of bytes in Hardware Init Code

KernelCodeOffset		ds.l	1			; 04c ; Offset of base of NanoKernel Code
KernelCodeSize			ds.l	1			; 050 ; Number of bytes in NanoKernel Code

EmulatorCodeOffset		ds.l	1			; 054 ; Offset of base of Emulator Code
EmulatorCodeSize		ds.l	1			; 058 ; Number of bytes in Emulator Code

OpcodeTableOffset		ds.l	1			; 05c ; Offset of base of Opcode Table
OpcodeTableSize			ds.l	1			; 060 ; Number of bytes in Opcode Table

BootstrapVersion		ds.b	16			; 064 ; Bootstrap loader version info
BootVersionOffset		ds.l	1			; 074 ; offset within EmulatorData of BootstrapVersion
ECBOffset				ds.l	1			; 078 ; offset within EmulatorData of ECB
IplValueOffset			ds.l	1			; 07c ; offset within EmulatorData of IplValue

EmulatorEntryOffset		ds.l	1			; 080 ; offset within Emulator Code of entry point
KernelTrapTableOffset	ds.l	1			; 084 ; offset within Emulator Code of KernelTrapTable

TestIntMaskInit			ds.l	1			; 088 ; initial value for test interrupt mask
ClearIntMaskInit		ds.l	1			; 08c ; initial value for clear interrupt mask
PostIntMaskInit			ds.l	1			; 090 ; initial value for post interrupt mask
LA_InterruptCtl			ds.l	1			; 094 ; logical address of Interrupt Control I/O page
InterruptHandlerKind	ds.b	1			; 098 ; kind of handler to use
						ds.b	3			; 099 ; filler

LA_InfoRecord			ds.l	1			; 09c ; logical address of InfoRecord page
LA_KernelData			ds.l	1			; 0a0 ; logical address of KernelData page
LA_EmulatorData			ds.l	1			; 0a4 ; logical address of EmulatorData page
LA_DispatchTable		ds.l	1			; 0a8 ; logical address of Dispatch Table
LA_EmulatorCode			ds.l	1			; 0ac ; logical address of Emulator Code

MacLowMemInitOffset		ds.l	1			; 0b0 ; offset to list of LowMem addr/data values

PageAttributeInit		ds.l	1			; 0b4 ; default WIMG/PP settings for PTE creation
PageMapInitSize			ds.l	1			; 0b8 ; size of page mapping info
PageMapInitOffset		ds.l	1			; 0bc ; offset to page mapping info (from base of ConfigInfo)
PageMapIRPOffset		ds.l	1			; 0c0 ; offset of InfoRecord map info (from base of PageMap)
PageMapKDPOffset		ds.l	1			; 0c4 ; offset of KernelData map info (from base of PageMap)
PageMapEDPOffset		ds.l	1			; 0c8 ; offset of EmulatorData map info (from base of PageMap)

SegMaps
SegMap32SupInit			ds.l	32			; 0cc ; 32 bit mode Segment Map Supervisor space
SegMap32UsrInit			ds.l	32			; 14c ; 32 bit mode Segment Map User space
SegMap32CPUInit			ds.l	32			; 1cc ; 32 bit mode Segment Map CPU space
SegMap32OvlInit			ds.l	32			; 24c ; 32 bit mode Segment Map Overlay mode

BATRangeInit			ds.l	32			; 2cc ; BAT mapping ranges

BatMap32SupInit			ds.l	1			; 34c ; 32 bit mode BAT Map Supervisor space
BatMap32UsrInit			ds.l	1			; 350 ; 32 bit mode BAT Map User space
BatMap32CPUInit			ds.l	1			; 354 ; 32 bit mode BAT Map CPU space
BatMap32OvlInit			ds.l	1			; 358 ; 32 bit mode BAT Map Overlay mode

SharedMemoryAddr		ds.l	1			; 35c ; physical address of Mac/Smurf shared message mem

PA_RelocatedLowMemInit	ds.l	1			; 360 ; physical address of RelocatedLowMem

OpenFWBundleOffset		ds.l	1			; 364 ; Offset of base of OpenFirmware PEF Bundle
OpenFWBundleSize		ds.l	1			; 368 ; Number of bytes in OpenFirmware PEF Bundle

LA_OpenFirmware			ds.l	1			; 36c ; logical address of Open Firmware
PA_OpenFirmware			ds.l	1			; 370 ; physical address of Open Firmware
LA_HardwarePriv			ds.l	1			; 374 ; logical address of HardwarePriv callback
						align	5			; pad to nice cache block alignment
						endr




;_______________________________________________________________________
;	System Info Record
;
;	Used to pass System information from the NanoKernel to user mode
;	software.
;_______________________________________________________________________

NKSystemInfoPtr			equ		$5FFFEFF0	; logical address of NKSystemInfo record
NKSystemInfoVer			equ		$5FFFEFF4	; version number of NKSystemInfo record
NKSystemInfoLen			equ		$5FFFEFF6	; length of NKSystemInfo record

kSystemInfoVer			equ		$0104

NKSystemInfo			record	0,increment
PhysicalMemorySize		ds.l	1			; 000 ; Number of bytes in Physical RAM
UsableMemorySize		ds.l	1			; 004 ; Number of bytes in Usable RAM
LogicalMemorySize		ds.l	1			; 008 ; Number of bytes in Logical RAM
HashTableSize			ds.l	1			; 00c ; Number of bytes in Memory Hash Table

L2DataCacheTotalSize	ds.l	1			; 010 ; number of bytes in the L2 Data Cache
L2InstCacheTotalSize	ds.l	1			; 014 ; number of bytes in the L2 Instruction Cache
L2CombinedCaches		ds.w	1			; 018 ; 1 <- combined or no cache, 0 <- split cache
L2InstCacheBlockSize	ds.w	1			; 01a ; number of bytes in a Block of the L2 Instruction Cache
L2DataCacheBlockSize	ds.w	1			; 01c ; number of bytes in a Block of the L2 Data Cache
L2InstCacheAssociativity ds.w	1			; 01e ; Associativity of the L2 Instruction Cache
L2DataCacheAssociativity ds.w	1			; 020 ; Associativity of the L2 Data Cache
						ds.b	2			; 022 ; unused

						ds.b	2			; 024 ; unused
FlashManufacturerCode	ds.b	1			; 026 ; Flash ROM Manufacturer code
FlashDeviceCode			ds.b	1			; 027 ; Flash ROM Device code
FlashStart				ds.l	1			; 028 ; Starting address of Flash ROM
FlashSize				ds.l	1			; 02c ; Number of bytes in  Flash ROM

Bank0Start				ds.l	1			; 030 ; Starting address of RAM bank 0
Bank0Size				ds.l	1			; 034 ; Number of bytes in  RAM bank 0
Bank1Start				ds.l	1			; 038 ; Starting address of RAM bank 1
Bank1Size				ds.l	1			; 03c ; Number of bytes in  RAM bank 1
Bank2Start				ds.l	1			; 040 ; Starting address of RAM bank 2
Bank2Size				ds.l	1			; 044 ; Number of bytes in  RAM bank 2
Bank3Start				ds.l	1			; 048 ; Starting address of RAM bank 3
Bank3Size				ds.l	1			; 04c ; Number of bytes in  RAM bank 3
Bank4Start				ds.l	1			; 050 ; Starting address of RAM bank 4
Bank4Size				ds.l	1			; 054 ; Number of bytes in  RAM bank 4
Bank5Start				ds.l	1			; 058 ; Starting address of RAM bank 5
Bank5Size				ds.l	1			; 05c ; Number of bytes in  RAM bank 5
Bank6Start				ds.l	1			; 060 ; Starting address of RAM bank 6
Bank6Size				ds.l	1			; 064 ; Number of bytes in  RAM bank 6
Bank7Start				ds.l	1			; 068 ; Starting address of RAM bank 7
Bank7Size				ds.l	1			; 06c ; Number of bytes in  RAM bank 7
Bank8Start				ds.l	1			; 070 ; Starting address of RAM bank 8
Bank8Size				ds.l	1			; 074 ; Number of bytes in  RAM bank 8
Bank9Start				ds.l	1			; 078 ; Starting address of RAM bank 9
Bank9Size				ds.l	1			; 07c ; Number of bytes in  RAM bank 9
Bank10Start				ds.l	1			; 080 ; Starting address of RAM bank 10
Bank10Size				ds.l	1			; 084 ; Number of bytes in  RAM bank 10
Bank11Start				ds.l	1			; 088 ; Starting address of RAM bank 11
Bank11Size				ds.l	1			; 08c ; Number of bytes in  RAM bank 11
Bank12Start				ds.l	1			; 090 ; Starting address of RAM bank 12
Bank12Size				ds.l	1			; 094 ; Number of bytes in  RAM bank 12
Bank13Start				ds.l	1			; 098 ; Starting address of RAM bank 13
Bank13Size				ds.l	1			; 09c ; Number of bytes in  RAM bank 13
Bank14Start				ds.l	1			; 0a0 ; Starting address of RAM bank 14
Bank14Size				ds.l	1			; 0a4 ; Number of bytes in  RAM bank 14
Bank15Start				ds.l	1			; 0a8 ; Starting address of RAM bank 15
Bank15Size				ds.l	1			; 0ac ; Number of bytes in  RAM bank 15
Bank16Start				ds.l	1			; 0b0 ; Starting address of RAM bank 16
Bank16Size				ds.l	1			; 0b4 ; Number of bytes in  RAM bank 16
Bank17Start				ds.l	1			; 0b8 ; Starting address of RAM bank 17
Bank17Size				ds.l	1			; 0bc ; Number of bytes in  RAM bank 17
Bank18Start				ds.l	1			; 0c0 ; Starting address of RAM bank 18
Bank18Size				ds.l	1			; 0c4 ; Number of bytes in  RAM bank 18
Bank19Start				ds.l	1			; 0c8 ; Starting address of RAM bank 19
Bank19Size				ds.l	1			; 0cc ; Number of bytes in  RAM bank 19
Bank20Start				ds.l	1			; 0d0 ; Starting address of RAM bank 20
Bank20Size				ds.l	1			; 0d4 ; Number of bytes in  RAM bank 20
Bank21Start				ds.l	1			; 0d8 ; Starting address of RAM bank 21
Bank21Size				ds.l	1			; 0dc ; Number of bytes in  RAM bank 21
Bank22Start				ds.l	1			; 0e0 ; Starting address of RAM bank 22
Bank22Size				ds.l	1			; 0e4 ; Number of bytes in  RAM bank 22
Bank23Start				ds.l	1			; 0e8 ; Starting address of RAM bank 23
Bank23Size				ds.l	1			; 0ec ; Number of bytes in  RAM bank 23
Bank24Start				ds.l	1			; 0f0 ; Starting address of RAM bank 24
Bank24Size				ds.l	1			; 0f4 ; Number of bytes in  RAM bank 24
Bank25Start				ds.l	1			; 0f8 ; Starting address of RAM bank 25
Bank25Size				ds.l	1			; 0fc ; Number of bytes in  RAM bank 25
EndOfBanks
						align	5			; pad to nice cache block alignment
MaxBanks				equ		26			; 16 banks, 0...15

											; Interrupt Support Data
IntCntrBaseAddr			ds.l	1			; 100 ; Interrupt Controller Base Address  (variable is used since this is a PCI Dev and address is relocatable)
IntPendingReg			ds.l 	2			; 104 ; Data of current interrupts pending register

											; These fields were added to report information about tightly-coupled L2 caches.
											; The inline L2 information should be used in situations where there is a CPU
											; card L2 cache that can coexist with a motherboard L2.

InlineL2DSize			ds.l	1			; 10c ; Size of in-line L2 Dcache
InlineL2ISize			ds.l	1			; 110 ; Size of in-line L2 Icache
InlineL2Combined		ds.w	1			; 114 ; 1 <- combined or no cache, 0 <- split cache
InlineL2IBlockSize		ds.w	1			; 116 ; Block size of in-line I L2 cache
InlineL2DBlockSize		ds.w	1			; 118 ; Block size of in-line D L2 cache
InlineL2IAssoc			ds.w	1			; 11a ; Associativity of L2 I
InlineL2DAssoc			ds.w	1			; 11c ; Associativity of L2 D
						ds.w	1			; 11e ; pad
Size					equ		*
						endr




;_______________________________________________________________________
;	Diagnostic Info Record
;
;	Used to pass Diagnostic information from the power on Diagnostics to
;	the NanoKernel, and from the NanoKernel to user mode software.
;_______________________________________________________________________

NKDiagInfoPtr			equ		$5FFFEFE8	; logical address of DiagnosticInfo record
NKDiagInfoVer			equ		$5FFFEFEC	; version number of DiagnosticInfo record
NKDiagInfoLen			equ		$5FFFEFEE	; length of DiagnosticInfo record

kDiagInfoVer			equ		$0100

NKDiagInfo				record	0,increment
BankMBFailOffset		ds.l	1			; 000 ; Mother Board RAM failure code
BankAFailOffset			ds.l	1			; 004 ; Bank A RAM failure code
BankBFailOffset			ds.l	1			; 008 ; Bank B RAM failure code
BankCFailOffset			ds.l	1			; 00c ; Bank C RAM failure code

BankDFailOffset			ds.l	1			; 010 ; Bank D RAM failure code
BankEFailOffset			ds.l	1			; 014 ; Bank E RAM failure code
BankFFailOffset			ds.l	1			; 018 ; Bank F RAM failure code
BankGFailOffset			ds.l	1			; 01c ; Bank G RAM failure code

BankHFailOffset			ds.l	1			; 020 ; Bank H RAM failure code
CacheFailOffset			ds.l	1			; 024 ; cache failure code
LongBootParamOffset		ds.l	1			; 028 ; on longBoot this is where the params will be
POSTTraceOffset			ds.l	1			; 02c ; this tells us what route the POST took

POSTOldWarmOffset		ds.l	1			; 030 ; logged address of old warmstart flag
POSTOldLongOffset		ds.l	1			; 034 ; logged address of old long boot flag
POSTOldGlobbOffset		ds.l	1			; 038 ; logged address of old Diagnostic Info Record
POSTOldParamOffset		ds.l	1			; 03c ; the params from the old diag globb

POSTStartRTCUOffset		ds.l	1			; 040 ; PPC Real Time Clock Upper at start of POST
POSTStartRTCLOffset		ds.l	1			; 044 ; PPC Real Time Clock Lower at start of POST
POSTEndRTCUOffset		ds.l	1			; 048 ; PPC Real Time Clock Upper at end of POST
POSTEndRTCLOffset		ds.l	1			; 04c ; PPC Real Time Clock Lower at end of POST

POSTTestTypeOffset		ds.l	1			; 050 ; when long RAM tests fail test type which failed is put here
POSTError2Offset		ds.l	1			; 054 ; result codes from tests
POSTError3Offset		ds.l	1			; 058 ; result codes from tests
POSTError4Offset		ds.l	1			; 05c ; result codes from tests

RegistersStore			ds.b	140			; 060 ; store all 60x registers here, still fit into 256 bytes size.

;	Everything BEFORE here is new (hence the funny-sized register store)

DiagPOSTResult2			ds.l	1			; 0ec ; POST results
DiagPOSTResult1			ds.l	1			; 0f0 ; POST results
DiagLongBootSig			ds.l	1			; 0f4 ; Burn in restart flag
DiagWarmStartHigh		ds.l	1			; 0f8 ; First long of native warm start  (WLSC)		<SM44>
DiagWarmStartLow		ds.l	1			; 0fc ; Second long of native warm start (SamB)		<SM44>
						align	5			; pad to nice cache block alignment
Size					equ		*
						endr




;_______________________________________________________________________
;	NanoKernel Info Record
;
;	Used to pass NanoKernel statistics from the NanoKernel to user mode
;	software.
;_______________________________________________________________________

NKNanoKernelInfoPtr		equ		$5FFFEFE0	; logical address of NanoKernelInfo record
NKNanoKernelInfoVer		equ		$5FFFEFE4	; version number of NanoKernelInfo record
NKNanoKernelInfoLen		equ		$5FFFEFE6	; length of NanoKernelInfo record

NKNanoKernelInfo		record	0,increment
ExceptionCauseCounts	ds.l	32			; 000 ; counters per exception cause
NanoKernelCallCounts	ds.l	16			; 080 ; counters per NanoKernel call
ExternalIntCount		ds.l	1			; 0c0 ; count of External Interrupts
MisalignmentCount		ds.l	1			; 0c4 ; count of Misalignment Interrupts
FPUReloadCount			ds.l	1			; 0c8 ; count of FPU reloads on demand
DecrementerIntCount		ds.l	1			; 0cc ; count of Decrementer Interrupts
QuietWriteCount			ds.l	1			; 0d0 ; count of Writes to Quiet Read-Only memory
HashTableCreateCount	ds.l	1			; 0d4 ; count of Hash Table Entry creations
HashTableDeleteCount	ds.l	1			; 0d8 ; count of Hash Table Entry deletions
HashTableOverflowCount	ds.l	1			; 0dc ; count of Hash Table Entry overflows
EmulatedUnimpInstCount	ds.l	1			; 0e0 ; count of Emulated unimplemented instructions
NCBPtrCacheMissCount	ds.l	1			; 0e4 ; count of NCB Pointer cache misses
ExceptionPropagateCount	ds.l	1			; 0e8 ; count of Exceptions propagated to system
ExceptionForcedCount	ds.l	1			; 0ec ; count of Exceptions forced to system
SysContextCpuTime		ds.l	2			; 0f0 ; CPU Time used by System Context
AltContextCpuTime		ds.l	2			; 0f8 ; CPU Time used by Alternate Context
Size					equ		*
						endr




;_______________________________________________________________________
;	Processor Info Record
;
;	Used to pass Processor information from the NanoKernel to user mode
;	software.
;_______________________________________________________________________

NKProcessorInfoPtr		equ		$5FFFEFD8	; logical address of ProcessorInfo record
NKProcessorInfoVer		equ		$5FFFEFDC	; version number of ProcessorInfo record
NKProcessorInfoLen		equ		$5FFFEFDE	; length of ProcessorInfo record

kProcessorInfoVer		equ		$0100

NKProcessorInfo			record	0,increment
ProcessorVersionReg		ds.l	1			; 000 ; contents of the PVR special purpose register
CpuClockRateHz			ds.l	1			; 004 ; CPU Clock frequency
BusClockRateHz			ds.l	1			; 008 ; Bus Clock frequency
DecClockRateHz			ds.l	1			; 00c ; Decrementer Clock frequency

Ovr
PageSize				ds.l	1			; 010 ; number of bytes in a memory page
DataCacheTotalSize		ds.l	1			; 014 ; number of bytes in the Data Cache
InstCacheTotalSize		ds.l	1			; 018 ; number of bytes in the Instruction Cache
CoherencyBlockSize		ds.w	1			; 01c ; number of bytes in a Coherency Block
ReservationGranuleSize	ds.w	1			; 01e ; number of bytes in a Reservation Granule
CombinedCaches			ds.w	1			; 020 ; 1 <- combined or no cache, 0 <- split cache
InstCacheLineSize		ds.w	1			; 022 ; number of bytes in a Line of the Instruction Cache
DataCacheLineSize		ds.w	1			; 024 ; number of bytes in a Line of the Data Cache
DataCacheBlockSizeTouch	ds.w	1			; 026 ; number of bytes in a Block for DCBT DCBTST
InstCacheBlockSize		ds.w	1			; 028 ; number of bytes in a Block of the Instruction Cache
DataCacheBlockSize		ds.w	1			; 02a ; number of bytes in a Block of the Data Cache
InstCacheAssociativity	ds.w	1			; 02c ; Associativity of the Instruction Cache
DataCacheAssociativity	ds.w	1			; 02e ; Associativity of the Data Cache

TransCacheTotalSize		ds.w	1			; 030 ; number of entries in the Translation Cache
TransCacheAssociativity	ds.w	1			; 032 ; Associativity of the Translation Cache
OvrEnd
						align	5			; pad to nice cache block alignment
Size					equ		*
						endr




;_______________________________________________________________________
;	Hardware Info Record
;
;	Used to pass hardware information from the NanoKernel to user mode
;	software.
;_______________________________________________________________________

NKHWInfoPtr				equ		$5FFFEFD0	; logical address of HWInfo record
NKHWInfoVer				equ		$5FFFEFD4	; version number of HWInfo record
NKHWInfoLen				equ		$5FFFEFD6	; length of HWInfo record

kHWInfoVer				equ		$0100

NKHWInfo				record	0,increment
											; interrupt pending bits (actively changing)

PendingInts				ds.l	2			; 028 ; 64 bits of pending interrupts

											; some Mac I/O device base addresses

ADB_Base				ds.l	1			; 030 ; base address of ADB
SCSI_DMA_Base			ds.l	1			; 034 ; base address of SCSI DMA registers

											; RTAS related stuff

RTAS_PrivDataArea		ds.l	1			; 038 ; RTAS private data area 
MacOS_NVRAM_Offset		ds.l	1			; 03c ; offset into nvram to MacOS data

RTAS_NVRAM_Fetch		ds.l	1			; 040 ; token for RTAS NVRAM fetch
RTAS_NVRAM_Store		ds.l	1			; 044 ; token for RTAS NVRAM store
RTAS_Get_Clock			ds.l	1			; 048 ; token for RTAS clock get
RTAS_Set_Clock			ds.l	1			; 04c ; token for RTAS clock set
RTAS_Restart			ds.l	1			; 050 ; token for RTAS Restart
RTAS_Shutdown			ds.l	1			; 054 ; token for RTAS Shutdown
RTAS_Restart_At			ds.l	1			; 058 ; token for RTAS system startup at specified time
RTAS_EventScan			ds.l	1			; 05c ; token for RTAS event scan
RTAS_Check_Exception	ds.l	1			; 060 ; token for RTAS check exception
RTAS_Read_PCI_Config	ds.l	1			; 064 ; token for RTAS read PCI config
RTAS_Write_PCI_Config	ds.l	1			; 068 ; token for RTAS write PCI config

											; SIO interrupt source numbers for the MPIC

SIOIntVect				ds.w	1			; 06c ; SIO (8259 cascade vector) vector number
SIOIntBit				ds.w	1			; 06e ; SIO (8259 cascade vector) bit number

Signature				ds.l	1			; 070 ; signature for this record ('Hnfo')

											; more interrupt source numbers

SpuriousIntVect			ds.w	1			; 074 ; spurious vector number

CPU_ID					ds.w	1			; 076 ; the ID of this CPU (universal-tables-related)

SCCAIntVect				ds.w	1			; 078 ; SCC A (non-DMA) vector number
SCCBIntVect				ds.w	1			; 07a ; SCC B (non-DMA) vector number
SCSIIntVect				ds.w	1			; 07c ; SCSI vector number
SCSIDMAIntVect			ds.w	1			; 07e ; SCSI DMA vector number
VIAIntVect				ds.w	1			; 080 ; VIA vector number
VIAIntBit				ds.w	1			; 082 ; VIA bit number
ADBIntVect				ds.w	1			; 084 ; vector number
NMIIntVect				ds.w	1			; 086 ; NMI vector number
NMIIntBit				ds.w	1			; 088 ; NMI bit number

											; current (actively changing) interrupt handling variables

ISAPendingInt			ds.w	1			; 08a ; currently pending ISA/8259 interrupt
CompletedInts			ds.b	8			; 08c ; completed interrupts

nkHWInfoFlagSlowMESH	equ		1			; set if fast MESH doesn't work on this box
nkHWInfoFlagAsynchMESH	equ		2			; set if Synchronous MESH doesn't work on this box
nkHWInfoFlagNoCopySWTLB	equ		4			; set if the software TLB walk code for 603 should NOT be copied
HardwareInfoFlags		ds.l	1			; 094 ; 32 bits of flags (see enum above)

RTAS_Get_PowerOn_Time	ds.l	1			; 098 ; token for RTAS getting time for system startup

						align	5			; pad to nice cache block alignment
 DS.B 96 ; no clue at all what these bytes are for, but they won't last
Size					equ		*
						endr
