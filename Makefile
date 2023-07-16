kernel_path = zig-out/bin/kernel.bin
qemu_args = -drive format=raw,file=os-image.bin -m 1G
bios = /Users/nwf/Desktop/oss/cpp/seabios/out/bios.bin
kernel_elf = zig-out/bin/zkernel

run: build
	qemu-system-i386 $(qemu_args) -serial stdio 

run_debug: build
	qemu-system-i386 $(qemu_args) -serial stdio -chardev stdio,id=seabios,debug=2000 -device isa-debugcon,iobase=0x402,chardev=seabios

build_kernel:
	zig build

build: build_kernel $(kernel_path)
	cd bootloader && zig build -Dkernel_size=$(shell stat -f%"z" $(kernel_path))
	cat bootloader/zig-out/bin/bootloader.bin $(kernel_path) > os-image.bin

clean:
	rm -rf zig-out/ zig-cache/
	rm os-image.bin
	rm -rf bootloader/zig-out/ bootloader/zig-cache/

	
monitor: build
	qemu-system-i386 $(qemu_args) -d int,guest_errors -no-reboot -no-shutdown -monitor stdio

debug: build
	qemu-system-i386 $(qemu_args) -serial stdio -s -S


debug_bios: build
	 qemu-system-i386 $(qemu_args) -chardev stdio,id=seabios -device isa-debugcon,iobase=0x402,chardev=seabios -m 512 -bios $(bios)

dump:
	x86_64-elf-objdump -D -mi386 zig-out/bin/zkernel | bat

sector_size:
	@echo "kernel sector size:" $$((($(shell stat -f%"z" $(kernel_path)) / 512) + 1))



grub_build: build_kernel
	-rm iso/os.iso
	cp $(kernel_elf) iso/boot/kernel.elf
	grub-mkrescue -o iso/os.iso iso/ > /dev/null

grub_run: grub_build
	qemu-system-i386 -boot d -cdrom iso/os.iso -m 128M -serial stdio 

grub_mon: grub_build
	qemu-system-i386 -boot d -cdrom iso/os.iso -d int,guest_errors -no-reboot -no-shutdown -monitor stdio

grub_dbios:
	qemu-system-i386 -boot d -cdrom iso/os.iso -chardev stdio,id=seabios -device isa-debugcon,iobase=0x402,chardev=seabios -m 512 -bios $(bios)

grub_clean:
	rm iso/os.iso
	rm iso/boot/kernel.elf

grub_debug:
	qemu-system-i386 -boot d -cdrom iso/os.iso -serial stdio -s -S
