pub const vga = @import("drivers/vga.zig");
pub const serial = @import("cpu/serial.zig");

const int = @import("interrupts/interrupts.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = @import("cpu/paging/paging.zig");
const mem = @import("cpu/paging/memmap.zig");
const std = @import("std");

fn halt() noreturn {
    asm volatile ("sti");
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    vga.writeln("panic: {s}", .{msg});
    while (true) {
        asm volatile ("cli");
    }
}

var HEAP_START: u32 = 0x10000;
const HEAP_SIZE: u32 = 100 * 1024; // 100 Kib
const HEAP_END = HEAP_START + HEAP_SIZE;

const BootInfo = struct { map_addr: u32, map_length: u32 };
export fn main(bootInfo: *BootInfo) noreturn {
    int.init();
    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);

    vga.writeln("boot info {}", .{bootInfo});
    var mem_map = @intToPtr([]mem.SMAPEntry, bootInfo.map_addr);
    mem_map.len = bootInfo.map_length;

    serial.init();
    serial.write("serial port initialized", .{});

    var frame = pg.FrameAllocator.init(mem_map);
    _ = frame.alloc() catch unreachable;

    halt();
}
