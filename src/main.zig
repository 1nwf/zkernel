pub const vga = @import("drivers/vga.zig");
const arch = @import("arch");
const gdt = arch.gdt;
pub const serial = arch.serial;

const int = @import("interrupts/interrupts.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = arch.paging;
const boot = @import("boot/mutliboot_header.zig");
const std = @import("std");
const pci = @import("drivers/pci/pci.zig");

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
    pub fn logFn(comptime _: std.log.Level, comptime _: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
        vga.writeln(format, args);
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

    const mem_aval = 0x00000040;
    vga.writeln("bootloader name: {s}", .{bootInfo.boot_loader_name});
    vga.writeln("header flags: 0b{b}", .{bootInfo.flags});
    vga.writeln("mem avail: {}", .{((bootInfo.flags & mem_aval) != 0)});

    const mem_map_length = bootInfo.mmap_length / @sizeOf(boot.MemMapEntry);
    vga.writeln("mmap length: {}", .{mem_map_length});

    const memMap: []boot.MemMapEntry = bootInfo.mmap_addr[0..mem_map_length];
    _ = memMap;
    arch.paging.init();
    pci.init();
}
