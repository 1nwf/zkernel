// Interrupt Descriptor Table
const std = @import("std");
const pic = @import("pic.zig");
const IDT = [256]Entry;
const write = @import("../drivers/vga.zig").write;
const writeln = @import("../drivers/vga.zig").writeln;

pub var idt: IDT = undefined;
pub var descriptor: IDTDescr = undefined;
const isr = @import("isr.zig");
const irq = @import("irq.zig");
const keyboard = @import("../drivers/keyboard.zig");
const timer = @import("timer.zig");

/// An Entry in the interrupt descriptor table
pub const Entry = packed struct {
    /// low bits of ISR (Interrupt Service Routine)
    isr_low: u16,
    /// the segment selector that the CPU will load into the code segment before calling the ISR
    selector: u16,
    /// reserved. set to zero
    reserved: u8,
    /// conatins gate type, cpu privelage level and present bit
    attributes: u8,
    /// high bits of ISR
    isr_high: u16,

    pub fn empty() Entry {
        return Entry{ .isr_low = 0, .selector = 0, .reserved = 0, .attributes = 0x8E, .isr_high = 0 };
    }
    pub fn init(handler: u32) Entry {
        return Entry{
            .isr_low = @truncate(u16, (handler & 0xFFFF)),
            .selector = 0x08, // index of code segment in gdt
            .reserved = 0,
            // --------------------------------------------------------------
            // present: 1 | DPL: 0 | Gate Type: 0xE (32 bit interrupt gate) |
            // --------------------------------------------------------------
            .attributes = 0x8E,
            .isr_high = @truncate(u16, (handler >> 16)),
        };
    }
};

/// idt descriptor that will be loaded using lidt
pub const IDTDescr = extern struct {
    /// 1 - size of idt in bytes
    size: u16,
    /// address of idt
    offset: u32 align(2),

    pub fn init(size: u16, offset: u32) IDTDescr {
        return IDTDescr{ .size = size, .offset = offset };
    }

    /// location of idt is stored in the IDTR (IDT register)
    pub fn load(self: *IDTDescr) void {
        asm volatile ("lidtl (%[descr])"
            :
            : [descr] "{eax}" (self),
        );
    }
};

pub fn init() void {
    disable();
    pic.remapPic(0x20, 0x28);
    keyboard.init_keyboard();
    timer.init_timer(30);
    idt = [_]Entry{Entry.init(@ptrToInt(&isr.isr_common))} ** 256;
    initExceptions();
    initInterrupts();
    descriptor = IDTDescr.init(@sizeOf(IDT) - 1, @ptrToInt(&idt));

    enable();
}

pub fn load() void {
    descriptor.load();
}

pub fn setHandler(
    idx: u8,
    func: u32,
) void {
    idt[idx] = Entry.init(func);
}

pub inline fn enable() void {
    asm volatile ("sti");
}

pub inline fn disable() void {
    asm volatile ("cli");
}

pub fn sidt() IDTDescr {
    var ptr = IDTDescr.init(0, 0);
    asm volatile ("sidt %[ptr]"
        : [ptr] "=m" (ptr),
    );
    return ptr;
}

pub fn initExceptions() void {
    const fns = [_]*const fn () callconv(.C) void{ isr.isr0, isr.isr1, isr.isr2, isr.isr3, isr.isr4, isr.isr5, isr.isr6, isr.isr7, isr.isr8, isr.isr9, isr.isr10, isr.isr11, isr.isr12, isr.isr13, isr.isr14, isr.isr15, isr.isr16, isr.isr17, isr.isr18, isr.isr19, isr.isr20, isr.isr21, isr.isr22, isr.isr23, isr.isr24, isr.isr25, isr.isr26, isr.isr27, isr.isr28, isr.isr29, isr.isr30, isr.isr31 };
    for (fns, 0..) |handler, i| {
        idt[i] = Entry.init(@ptrToInt(handler));
    }
}

pub fn initInterrupts() void {
    const fns = [_]*const fn () callconv(.C) void{ irq.irq0, irq.irq1, irq.irq2, irq.irq3, irq.irq4, irq.irq5, irq.irq6, irq.irq7, irq.irq8, irq.irq9, irq.irq10, irq.irq11, irq.irq12, irq.irq13, irq.irq14, irq.irq15 };
    for (fns, 32..) |handler, i| {
        idt[i] = Entry.init(@ptrToInt(handler));
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
