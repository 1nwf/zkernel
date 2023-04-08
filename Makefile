kernel_path = zig-out/bin/kernel.bin

run: build_kernel $(kernel_path)
	cd bootloader && zig build -Dkernel_size=$(shell stat -f%"z" $(kernel_path))
	cat bootloader/zig-out/bin/bootloader.bin $(kernel_path) > os-image.bin
	qemu-system-i386 -fda os-image.bin

build_kernel:
	zig build
	
clean:
	rm -rf zig-out/ zig-cache/
	rm os-image.bin
	rm -rf bootloader/zig-out/ bootloader/zig-cache/

	
