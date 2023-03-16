const vga = @import("drivers/vga.zig");
const int = @import("interrupts/idt.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");

// kernel entry
// has custom .entry section that is placed first in the .text section
export fn entry() void {
    main() catch {};
}

fn halt() noreturn {
    asm volatile ("sti");
    while (true) {
        asm volatile ("hlt");
    }
}

var HEAP_START: u32 = 0x10000;
const HEAP_SIZE: u32 = 108 * 1024; // 100 Kib
const HEAP_END = HEAP_START + HEAP_SIZE;

fn main() !noreturn {
    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);
    int.enable();
    int.init();
    int.load();

    var fl = heap.FreeListAllocator.init(HEAP_START, HEAP_SIZE);
    const val = try fl.alloc(u32, 12);

    vga.writeln("val1 {*} {}", .{ val, val.* });

    fl.nodes();
    var val2 = try fl.alloc(u64, 20);
    vga.writeln("val2: {*} {}", .{ val2, val2.* });

    fl.nodes();

    fl.free(val2);
    fl.nodes();

    fl.free(val);
    fl.nodes();

    halt();
}
