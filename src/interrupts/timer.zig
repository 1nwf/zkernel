const int = @import("interrupts.zig");
const idt = @import("idt.zig");
const io = @import("arch").io;
const arch = @import("arch");
const pic = @import("pic.zig");

const log = @import("std").log;

const process_scheduler = @import("../process/scheduler.zig");
const timer_interrupt_handler = arch.interrupt_handler(timer_handler);

pub fn init_timer(freq: u32) void {
    idt.setHandler(32, @intFromPtr(&timer_interrupt_handler), 0);

    const divisor: u16 = @truncate(1193180 / freq);
    const low: u8 = @truncate(divisor / 0xFF);
    const high: u8 = @truncate((divisor >> 8) & 0xFF);

    io.out(0x40, low);
    io.out(0x40, high);

    interval = freq;
}

var ticks: u32 = 0;
var interval: u32 = 0;

pub export fn timer_handler(ctx: arch.thread.Context) usize {
    ticks += 1;
    var next_ctx: usize = 0;
    if (process_scheduler.run_next(ctx)) |c| {
        next_ctx = @intFromPtr(c);
    }

    pic.sendEoi(0);
    return next_ctx;
}

pub fn read_count() u16 {
    var count: u16 = 0;

    io.out(0x43, @as(u8, 0));
    var low = io.in(0x40, u8);
    var high = io.in(0x40, u8);

    count = high;
    count = (count << 8) | low;

    return count;
}

pub export fn wait(secs: u32) void {
    var target = ticks + (secs * interval);
    while (ticks < target) {
        asm volatile ("hlt");
    }

    return;
}
