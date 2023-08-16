const std = @import("std");
const log = std.log.scoped(.default);

const arch = @import("arch");
const serial = arch.serial;
const vga = @import("drivers/vga.zig");
const gdt = arch.gdt;

const int = @import("interrupts/interrupts.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = arch.paging;
const boot = @import("boot/mutliboot_header.zig");
const pci = @import("drivers/pci/pci.zig");

const vmm = @import("vmm/vmm.zig");

inline fn halt() noreturn {
    int.enable();
    while (true) {
        asm volatile ("hlt");
    }
}

export fn kmain(bootInfo: *boot.MultiBootInfo) noreturn {
    main(bootInfo) catch {};
    halt();
}

pub const std_options = struct {
    pub fn logFn(comptime _: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
        if (scope != .default) serial.write("{s}: ", .{@tagName(scope)});
        serial.writeln(format, args);
    }
};

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    serial.write("panic: {s}", .{msg});
    halt();
}

extern const kernel_start: usize;
extern const kernel_end: usize;

fn main(bootInfo: *boot.MultiBootInfo) !void {
    gdt.init();
    int.init();
    serial.init();
    vga.init(.{ .bg = .LightRed }, .Underline);

    vga.writeln("bootloader name: {s}", .{bootInfo.boot_loader_name});
    vga.writeln("header flags: 0b{b}", .{bootInfo.flags});

    const mem_map_length = bootInfo.mmap_length / @sizeOf(boot.MemMapEntry);
    vga.writeln("mmap length: {}", .{mem_map_length});

    const mem_map: []boot.MemMapEntry = bootInfo.mmap_addr[0..mem_map_length];
    var reserved_mem_regions = [_]vmm.MemoryRegion{
        vmm.MemoryRegion.init(@intFromPtr(&kernel_start), @intFromPtr(&kernel_end)),
        vmm.MemoryRegion.init(0xb8000, 0xb8000 + (25 * 80)), // frame buffer
    };

    _ = vmm.init(mem_map, &reserved_mem_regions);
    pci.init();
}
