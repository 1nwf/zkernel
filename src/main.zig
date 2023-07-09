pub const vga = @import("drivers/vga.zig");
const gdt = @import("cpu/gdt.zig");
pub const serial = @import("cpu/serial.zig");

const int = @import("interrupts/interrupts.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = @import("cpu/paging/paging.zig");
const mem = @import("cpu/paging/memmap.zig");
const std = @import("std");

const boot = @import("boot/mutliboot_header.zig");

inline fn halt() noreturn {
    int.enable();
    while (true) {
        asm volatile ("hlt");
    }
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

// const BootInfo = struct { mem_map: []mem.MemMapEntry };

export fn main(bootInfo: *boot.MultiBootInfo) noreturn {
    _ = bootInfo;
    gdt.init();
    int.init();
    serial.init();
    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);

    vga.writeln("hello", .{});

    halt();
}
