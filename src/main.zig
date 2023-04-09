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

const BootInfo = struct { mapAddr: u32, size: u32 };

const MemMapEntry = extern struct {
    base: u64,
    length: u64,
    type: u32,
    acpi: u32,
};

export fn main(bootInfoAddr: u32) void {
    int.init();
    int.load();

    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);

    vga.writeln("boot info addr {x}", .{bootInfoAddr});

    const bootInfo = @intToPtr(*BootInfo, bootInfoAddr);

    vga.writeln("ptr is {}", .{bootInfo});
    var map = @intToPtr([]MemMapEntry, bootInfo.mapAddr);

    for (0..bootInfo.size) |i| {
        vga.writeln("{}", .{map[i]});
    }

    halt();
}
