; These "include" directives mean "Insert this file's contents here."

    include 'PPCInfoRecordsPriv.s'
    include 'Macros.s'
    include 'Defines.s'
CodeBase
    include 'Init.s'
CrashMRInts
CrashPageTable
CrashExceptions
CrashSoftInts
CrashVirtualMem
    include 'Crash.s'
    include 'HotInts.s'
    _align 10
MRBase
    include 'MROptabCode.s'
    include 'MRMemtabCode.s'
    include 'MRInts.s'
    include 'MROptab.s'
    include 'MRMemtab.s'
    include 'MRRestab.s'
    include 'ColdInts.s'
    include 'PageTable.s'
    include 'Exceptions.s'
    include 'Floats.s'
    include 'Emulate.s'
    include 'SoftInts.s'
    include 'VirtualMem.s'
    include 'Power.s'
    include 'ExternalInts.s'
