const idt = @import("idt.zig");
const pic = @import("pic.zig");
const keyboard = @import("../drivers/keyboard.zig");
const timer = @import("timer.zig");
const isr = @import("isr.zig");
const irq = @import("irq.zig");
const arch = @import("arch");
const log = @import("std").log.scoped(.int);
const syscalls = @import("../syscalls/syscalls.zig");

const page_fault_interrupt_handler = @import("page_fault.zig").page_fault_interrupt_handler;
const default_interrupt_handler = arch.interrupt_handler(default_handler);

const IrqHandler = *const fn () callconv(.C) void;
const IsrHandler = *const fn () callconv(.C) void;

pub fn init() void {
    disable();
    pic.remapPic(0x20, 0x28);
    idt.idt = [_]idt.Entry{idt.Entry.init(@intFromPtr(&default_interrupt_handler), 3)} ** 256;

    keyboard.init_keyboard();
    timer.init_timer(20);
    idt.setHandler(@as(u8, 48), @intFromPtr(&syscalls.syscall_int_handler), 3);
    idt.setHandler(14, @intFromPtr(&page_fault_interrupt_handler), 0);

    idt.descriptor = idt.IDTDescr.init(@sizeOf(idt.IDT) - 1, @intFromPtr(&idt.idt));
    idt.descriptor.load();
    enable();
}

pub fn setIrqHandler(num: u8, func: usize) void {
    idt.setHandler(num + 32, func, 0);
}

pub inline fn enable() void {
    asm volatile ("sti");
}

pub inline fn disable() void {
    asm volatile ("cli");
}

pub fn initExceptions() void {
    for (isr.isr_handlers, 0..) |handler, i| {
        idt.setHandler(@as(u8, @truncate(i)), @intFromPtr(handler), 0);
    }

    idt.setHandler(@as(u8, 48), @intFromPtr(&syscalls.syscall_int_handler), 3);
}

pub fn initInterrupts() void {
    for (irq.irq_handlers, 32..) |handler, i| {
        idt.setHandler(@as(u8, @truncate(i)), @intFromPtr(handler), 0);
    }
}

export fn default_handler(_: arch.thread.Context) usize {
    log.err("interrupt triggered", .{});
    return 0;
}
