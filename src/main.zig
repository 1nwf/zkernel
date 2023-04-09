const vga = @import("drivers/vga.zig");
const int = @import("interrupts/idt.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = @import("cpu/paging/paging.zig");

fn halt() noreturn {
    asm volatile ("sti");
    while (true) {
        asm volatile ("hlt");
    }
}

var HEAP_START: u32 = 0x10000;
const HEAP_SIZE: u32 = 108 * 1024; // 100 Kib
const HEAP_END = HEAP_START + HEAP_SIZE;

export fn main() void {
    int.init();
    int.load();

    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);

    vga.writeln("Kernel Loaded", .{});

    halt();
}
