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

pub fn setHandler(
    idx: u8,
    func: u32,
) void {
    idt[idx] = Entry.init(func);
}

pub fn sidt() IDTDescr {
    var ptr = IDTDescr.init(0, 0);
    asm volatile ("sidt %[ptr]"
        : [ptr] "=m" (ptr),
    );
    return ptr;
}
