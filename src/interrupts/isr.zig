const int = @import("idt.zig");
const writeln = @import("../drivers/vga.zig").writeln;

pub export fn isr_handler() callconv(.Naked) void {
    writeln("interrupt occured", .{});
}
pub export fn isr_common() void {
    int.disable();
    asm volatile ("call isr_handler");
    int.enable();
    asm volatile ("iret");
}

// zig fmt: off
const Context = extern struct {
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

