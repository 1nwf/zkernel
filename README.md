# zkernel
an operating system kernel developed for learning purposes.

## Tasks:
- [x] create and load kernel GDT
- [x] logging via serial ports
- [x] write to the screen using the frame buffer
- [x] initialize interrupt descriptor table
- [x] setup physical memory manager
- [x] setup virtual memory management and paging
- [x] create keyboard driver
- [ ] create nic (network interface card) driver
- [ ] create disk driver (ata/ide)
- [ ] create a filesystem (FAT?)
- [ ] remove makefile and utilize zig build system for linking kernel + bootloader, running in qemu, and other cmds.

## Possible Future Goals:
- [ ] have partial compatibility with the linux ABI. Can execute simple linux binaries
