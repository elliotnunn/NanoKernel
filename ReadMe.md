These are reverse-engineered PowerPC assembly sources of the [Mac OS
NanoKernel](https://en.wikipedia.org/wiki/Mac_OS_nanokernel). The work
of reversing this unusual operating system kernel has been part of the
[*CDG5*](https://github.com/elliotnunn/cdg5) project.

Different git branches of this repository build different versions of
the NanoKernel. The `master` branch builds a byte-perfect copy of the
first public release, which is found in the ROM of the first "Piltdown
Man" series of Power Macintoshes. Other `master-*` branches build
subsequent versions, through the multitasking v2.x series right up to
the final public v2.28 release.

A binary of the NanoKernel shipped inside the 4 MB mask ROM of every
"OldWorld" PowerPC Mac, and inside the disk-based "Mac OS ROM" file for
"NewWorld" PowerPC Macs. Mac OS 8.6 and later also shipped with a
disk-based kernel in the System file (resource 'krnl' 0), which can
replace the running ROM-based kernel part-way through the boot process
OldWorld system.


# Building

These sources can be built by Apple's `PPCAsm` assembler with the help
of ksherlock's [mpw](https://github.com/ksherlock/mpw) runtime
environment. A Python script neatly wraps the build process and provides
commentary on the standard output. The NanoKernel binary is packaged
into several useful formats named `NanoKernelBuild*`.

	./EasyBuild


# Running Release History

## PDM 601 1.0

First Power Macintosh!

- 1994-03-14 Power Mac 6100, 7100, 8100
- 1994-04-25 Workgroup Server 9150
