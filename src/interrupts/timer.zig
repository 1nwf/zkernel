const int = @import("interrupts.zig");
const io = @import("arch").io;
const write = @import("../drivers/vga.zig").write;

pub fn init_timer(freq: u32) void {
    int.setIrqHandler(0, timer_handler);
    const divisor: u16 = @truncate(1193180 / freq);
    const low: u8 = @truncate(divisor / 0xFF);
    const high: u8 = @truncate((divisor >> 8) & 0xFF);

    io.out(0x40, low);
    io.out(0x40, high);

    interval = freq;
}

var ticks: u32 = 0;
var interval: u32 = 0;

pub export fn timer_handler(_: int.Context) void {
    ticks += 1;
}

pub fn read_count() u16 {
    var count: u16 = 0;

    io.out(0x43, @as(u8, 0));
    const low = io.in(0x40, u8);
    const high = io.in(0x40, u8);

    count = high;
    count = (count << 8) | low;

    return count;
}

pub fn wait(ms: u32) void {
    var target = ticks + ms;
    while (ticks < target) {
        asm volatile ("hlt");
    }
    return;
}
