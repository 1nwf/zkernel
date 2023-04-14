kernel_path = zig-out/bin/kernel.bin

run: build
	qemu-system-i386 -drive format=raw,file=os-image.bin

build_kernel:
	zig build

build: build_kernel $(kernel_path)
	cd bootloader && zig build -Dkernel_size=$(shell stat -f%"z" $(kernel_path))
	cat bootloader/zig-out/bin/bootloader.bin $(kernel_path) > os-image.bin

clean:
	rm -rf zig-out/ zig-cache/
	rm os-image.bin
	rm -rf bootloader/zig-out/ bootloader/zig-cache/

	
