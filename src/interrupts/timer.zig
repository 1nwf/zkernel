const int = @import("interrupts.zig");
const out = @import("../io.zig").out;
const in = @import("../io.zig").in;
const write = @import("../drivers/vga.zig").write;

pub fn init_timer(freq: u32) void {
    int.setIrqHandler(0, timer_handler);
    const divisor: u16 = @truncate(u16, 1193180 / freq);
    const low = @truncate(u8, divisor / 0xFF);
    const high = @truncate(u8, (divisor >> 8) & 0xFF);

    out(0x40, low);
    out(0x40, high);

    interval = freq;
}

var ticks: u32 = 0;
var interval: u32 = 0;

pub export fn timer_handler(ctx: int.Context) void {
    _ = ctx;
    ticks += 1;
}

pub fn read_count() u16 {
    var count: u16 = 0;

    out(0x43, @as(u8, 0));
    var low = in(0x40, u8);
    var high = in(0x40, u8);

    count = high;
    count = (count << 8) | low;

    return count;
}

pub export fn wait(secs: u32) void {
    var target = ticks + (secs * interval);
    while (ticks < target) {
        asm volatile ("nop");
    }

    return;
}
