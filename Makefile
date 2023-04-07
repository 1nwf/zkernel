build:
	zig build
	zig build bin
	zig build --build-file bootloader/build.zig
	cat bootloader/zig-out/bin/bootloader.bin kernel.bin > os-image.bin
	qemu-system-i386 -fda os-image.bin
	
clean:
	rm -rf zig-out/ zig-cache/
	rm kernel.bin os-image.bin
	rm -rf bootloader/zig-out/ bootloader/zig-cache/

	
