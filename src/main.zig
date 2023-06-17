pub const vga = @import("drivers/vga.zig");
pub const serial = @import("cpu/serial.zig");

const int = @import("interrupts/interrupts.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = @import("cpu/paging/paging.zig");
const mem = @import("cpu/paging/memmap.zig");
const std = @import("std");

inline fn halt() noreturn {
    int.enable();
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    serial.write("panic: {s}", .{msg});
    halt();
}

const HEAP_START: u32 = 0x10000;
const HEAP_SIZE: u32 = 100 * 1024; // 100 Kib
const HEAP_END = HEAP_START + HEAP_SIZE;

const BootInfo = struct { mem_map: []mem.SMAPEntry };
export fn main(bootInfo: *BootInfo) noreturn {
    int.init();
    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);

    vga.writeln("boot info: {}", .{bootInfo});

    for (bootInfo.mem_map) |entry| {
        vga.writeln("mem map entry: {x} ... {x}", .{ entry.base, entry.length });
    }

    serial.init();
    serial.write("serial port initialized", .{});
    halt();
}
