const int = @import("interrupts.zig");
const writeln = @import("../drivers/vga.zig").writeln;
const arch = @import("arch");

export fn isr_handler(ctx: int.Context) void {
    const handler = int.interrupt_handlers[ctx.int_num];
    handler(ctx);
    arch.halt();
}

pub export fn isr_common() callconv(.Naked) void {
    asm volatile (
        \\ cli
        \\ pusha
        \\ mov %%ds, %%ax
        \\ push %%eax // push data segment
        \\
        \\ call isr_handler
        \\
        \\ pop %%eax
        \\ popa
        \\ add $8, %%esp
        \\ sti
        \\ iret
    );
}

pub fn isr(comptime num: usize) void {
    asm volatile (
        \\ cli
        \\ push $0 
        \\ push %[num]
        \\ jmp isr_common
        :
        : [num] "i" (num),
    );
}

pub export fn isr0() void {
    isr(0);
}

pub export fn isr1() void {
    isr(1);
}

pub export fn isr2() void {
    isr(2);
}

pub export fn isr3() void {
    isr(3);
}

pub export fn isr4() void {
    isr(4);
}

pub export fn isr5() void {
    isr(5);
}

pub export fn isr6() void {
    isr(6);
}

pub export fn isr7() void {
    isr(7);
}

pub export fn isr8() void {
    isr(8);
}

pub export fn isr9() void {
    isr(9);
}

pub export fn isr10() void {
    isr(10);
}

pub export fn isr11() void {
    isr(11);
}

pub export fn isr12() void {
    isr(12);
}

pub export fn isr13() void {
    isr(13);
}

pub export fn isr14() void {
    isr(14);
}

pub export fn isr15() void {
    isr(15);
}

pub export fn isr16() void {
    isr(16);
}

pub export fn isr17() void {
    isr(17);
}

pub export fn isr18() void {
    isr(18);
}

pub export fn isr19() void {
    isr(19);
}

pub export fn isr20() void {
    isr(20);
}

pub export fn isr21() void {
    isr(21);
}

pub export fn isr22() void {
    isr(22);
}

pub export fn isr23() void {
    isr(23);
}

pub export fn isr24() void {
    isr(24);
}

pub export fn isr25() void {
    isr(25);
}

pub export fn isr26() void {
    isr(26);
}

pub export fn isr27() void {
    isr(27);
}

pub export fn isr28() void {
    isr(28);
}

pub export fn isr29() void {
    isr(29);
}
pub export fn isr30() void {
    isr(30);
}

pub export fn isr31() void {
    isr(31);
}
