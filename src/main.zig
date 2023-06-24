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

pub const std_options = struct {
    pub fn logFn(comptime _: std.log.Level, comptime _: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
        vga.writeln(format, args);
    }
};

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    serial.write("panic: {s}", .{msg});
    halt();
}

const HEAP_START: u32 = 0x10000;
const HEAP_SIZE: u32 = 100 * 1024; // 100 Kib
const HEAP_END = HEAP_START + HEAP_SIZE;

const BootInfo = struct { mem_map: []mem.MemMapEntry };

pub extern var kernel_start: usize;
pub extern var kernel_end: usize;
export fn main(bootInfo: *BootInfo) noreturn {
    int.init();
    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);

    kernel_start = @ptrToInt(&kernel_start);
    kernel_end = @ptrToInt(&kernel_end);

    vga.writeln("kernel start: 0x{x}", .{kernel_start});
    vga.writeln("kernel end: 0x{x}", .{kernel_end});
    std.log.info("std.log.info()", .{});

    for (bootInfo.mem_map) |entry| {
        vga.writeln("mem map entry: {x} ... {x}", .{ entry.base, entry.length });
    }

    serial.init();
    serial.write("serial port initialized", .{});

    var frame_alloc = pg.FrameAllocator.init(bootInfo.mem_map);
    vga.writeln("frame count: {}", .{frame_alloc.count});

    halt();
}
