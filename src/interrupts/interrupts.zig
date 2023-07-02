const idt = @import("idt.zig");
const pic = @import("pic.zig");
const keyboard = @import("../drivers/keyboard.zig");
const timer = @import("timer.zig");
const isr = @import("isr.zig");
const irq = @import("irq.zig");

pub fn init() void {
    disable();
    pic.remapPic(0x20, 0x28);
    keyboard.init_keyboard();
    timer.init_timer(20);
    idt.idt = [_]idt.Entry{idt.Entry.init(@intFromPtr(&isr.isr_common))} ** 256;
    initExceptions();
    initInterrupts();
    idt.descriptor = idt.IDTDescr.init(@sizeOf(idt.IDT) - 1, @intFromPtr(&idt.idt));
    idt.descriptor.load();
    enable();
}

pub inline fn enable() void {
    asm volatile ("sti");
}

pub inline fn disable() void {
    asm volatile ("cli");
}

pub fn initExceptions() void {
    const fns = [_]*const fn () callconv(.C) void{ isr.isr0, isr.isr1, isr.isr2, isr.isr3, isr.isr4, isr.isr5, isr.isr6, isr.isr7, isr.isr8, isr.isr9, isr.isr10, isr.isr11, isr.isr12, isr.isr13, isr.isr14, isr.isr15, isr.isr16, isr.isr17, isr.isr18, isr.isr19, isr.isr20, isr.isr21, isr.isr22, isr.isr23, isr.isr24, isr.isr25, isr.isr26, isr.isr27, isr.isr28, isr.isr29, isr.isr30, isr.isr31 };
    for (fns, 0..) |handler, i| {
        idt.setHandler(@as(u8, @truncate(i)), @intFromPtr(handler));
    }
}

pub fn initInterrupts() void {
    const fns = [_]*const fn () callconv(.C) void{ irq.irq0, irq.irq1, irq.irq2, irq.irq3, irq.irq4, irq.irq5, irq.irq6, irq.irq7, irq.irq8, irq.irq9, irq.irq10, irq.irq11, irq.irq12, irq.irq13, irq.irq14, irq.irq15 };
    for (fns, 32..) |handler, i| {
        idt.setHandler(@as(u8, @truncate(i)), @intFromPtr(handler));
    }
}

export fn default_handler(ctx: Context) void {
    _ = ctx;
}
pub var interrupt_handlers = [_]Handler{default_handler} ** 256;
const Handler = *const fn (Context) callconv(.C) void;
pub fn setIrqHandler(comptime idx: usize, comptime h: Handler) void {
    interrupt_handlers[idx + 32] = h;
}

pub fn setExceptionHandler(comptime idx: usize, comptime h: Handler) void {
    interrupt_handlers[idx] = h;
}

// zig fmt: off
pub const Context = extern struct {
    ds: u32,
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,
    int_num: u32,
    err_code: u32,
    // cpu automatically pushes these values to the stack when an interrupt occurs
    eip: u32, // instruction pointer
    cs: u32, // code segment
    eflags: u32, // cpu flags
    uesp: u32, // stack pointer of interrupt code
    ss: u32 // stack segment
};
