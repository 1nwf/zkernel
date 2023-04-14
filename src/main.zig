const vga = @import("drivers/vga.zig");
const int = @import("interrupts/interrupts.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = @import("cpu/paging/paging.zig");
const mem = @import("cpu/paging/memmap.zig");

fn halt() noreturn {
    asm volatile ("sti");
    while (true) {
        asm volatile ("hlt");
    }
}

var HEAP_START: u32 = 0x10000;
const HEAP_SIZE: u32 = 108 * 1024; // 100 Kib
const HEAP_END = HEAP_START + HEAP_SIZE;

const BootInfo = struct { map_addr: u32, map_length: u32 };
export fn main(bootInfo: *BootInfo) noreturn {
    int.init();

    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);

    vga.writeln("boot info {}", .{bootInfo});
    var mem_map = @intToPtr([]mem.SMAPEntry, bootInfo.map_addr);
    mem_map.len = bootInfo.map_length;

    var frame_alloc = pg.FrameAllocator.init(mem_map, HEAP_START);
    for (frame_alloc.frames) |frame| {
        vga.write("[{} - {}] - ", .{ frame.start, frame.end });
    }

    halt();
}
