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

- all 1994 Power Macs (6100/7100/8100 and Workgroup Servers)

## PDM 601 1.1

- early-1995 PDM spec bump

## Cordyceps 6

- built 1995-03-24 Power Mac/Performa 5200, 5300, 6200, 6300

## TNT 0.1, PBX 603 0.0

- 1995-04-21 Power Mac 7200, 7500, 8500, 9500
- 1995-05-18 Power Mac 7200, 7500, 8500, 9500
- 1995-06-29 PowerBook 2300 (and 500 series PowerPC upgrade)

