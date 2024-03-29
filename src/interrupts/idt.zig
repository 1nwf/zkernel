// Interrupt Descriptor Table
const std = @import("std");
const pic = @import("pic.zig");
pub const IDT = [256]Entry;
const write = @import("../drivers/vga.zig").write;
const writeln = @import("../drivers/vga.zig").writeln;

pub var idt: IDT = undefined;
pub var descriptor: IDTDescr = undefined;

/// An Entry in the interrupt descriptor table
pub const Entry = packed struct {
    /// low bits of ISR (Interrupt Service Routine)
    isr_low: u16,
    /// the segment selector that the CPU will load into the code segment before calling the ISR
    selector: u16,
    /// reserved. set to zero
    reserved: u8,
    gate_type: u4 = 0xE,
    zero: u1 = 0,
    dpl: u2,
    present: u1 = 1,
    /// high bits of ISR
    isr_high: u16,

    pub fn empty() Entry {
        return Entry{ .isr_low = 0, .selector = 0, .reserved = 0, .attributes = 0x8E, .isr_high = 0 };
    }
    pub fn init(handler: usize, dpl: u2) Entry {
        return Entry{
            .isr_low = @truncate((handler & 0xFFFF)),
            .selector = 0x8, // index of code segment in gdt
            .reserved = 0,
            .dpl = dpl,
            .isr_high = @truncate((handler >> 16)),
        };
    }
};

/// idt descriptor that will be loaded using lidt
pub const IDTDescr = extern struct {
    /// 1 - size of idt in bytes
    size: u16,
    /// address of idt
    offset: usize align(2),

    pub fn init(size: u16, offset: usize) IDTDescr {
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

pub fn setHandler(idx: u8, func: usize, dpl: u2) void {
    idt[idx] = Entry.init(func, dpl);
}

pub fn sidt() IDTDescr {
    var ptr = IDTDescr.init(0, 0);
    asm volatile ("sidt %[ptr]"
        : [ptr] "=m" (ptr),
    );
    return ptr;
}
