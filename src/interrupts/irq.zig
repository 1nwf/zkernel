const writeln = @import("../drivers/vga.zig").writeln;
const write = @import("../drivers/vga.zig").write;
const int = @import("interrupts.zig");
const Context = @import("interrupts.zig").Context;
const sendEoi = @import("pic.zig").sendEoi;

// TODO: queue interrupts instead of handling them immediately
export fn irq_handler(ctx: Context) void {
    const handler = int.interrupt_handlers[ctx.err_code];
    handler(ctx);
    sendEoi(ctx.int_num);
}

export fn irq_common() callconv(.Naked) void {
    asm volatile (
        \\ cli
        \\ pusha
        \\ mov %%ds, %%ax
        \\ push %%eax // push data segment
        \\ mov $0x10 , %%ax // gdt data segment index
        \\
        \\ mov %%ax, %%ds
        \\ mov %%ax, %%es
        \\ mov %%ax, %%gs
        \\ mov %%ax, %%fs
        \\
        \\ call irq_handler
        \\
        \\ pop %%ebx
        \\ mov  %%bx, %%ds
        \\ mov  %%bx, %%es
        \\ mov  %%bx, %%gs
        \\ mov  %%bx, %%fs
        \\ popa
        \\ add $8, %%esp
        \\ sti
        // removes CS, EIP, EFLAGS, SS, and ESP from the stack
        \\ iret 
    );
}

pub fn irq(comptime num: usize) void {
    asm volatile (
        \\ cli
        \\ push %[n1] 
        \\ push %[n2]
        \\ jmp irq_common
        :
        : [n1] "i" (num + 32),
          [n2] "i" (num),
    );
}

pub export fn irq0() void {
    irq(0);
}

pub export fn irq1() void {
    irq(1);
}

pub export fn irq2() void {
    irq(2);
}

pub export fn irq3() void {
    irq(3);
}

pub export fn irq4() void {
    irq(4);
}

pub export fn irq5() void {
    irq(5);
}

pub export fn irq6() void {
    irq(6);
}

pub export fn irq7() void {
    irq(7);
}

pub export fn irq8() void {
    irq(8);
}

pub export fn irq9() void {
    irq(9);
}

pub export fn irq10() void {
    irq(10);
}

pub export fn irq11() void {
    irq(11);
}

pub export fn irq12() void {
    irq(12);
}

pub export fn irq13() void {
    irq(13);
}

pub export fn irq14() void {
    irq(14);
}

pub export fn irq15() void {
    irq(15);
}
