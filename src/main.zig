const vga = @import("drivers/vga.zig");
const int = @import("interrupts/idt.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = @import("cpu/paging/paging.zig");

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

    pg.enable_paging();

    halt();
}
