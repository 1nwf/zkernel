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

pub export fn isr0() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $0
        \\ jmp isr_common
    );
}

pub export fn isr1() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $1
        \\ jmp isr_common
    );
}

pub export fn isr2() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $2
        \\ jmp isr_common
    );
}

pub export fn isr3() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $3
        \\ jmp isr_common
    );
}

pub export fn isr4() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $4
        \\ jmp isr_common
    );
}

pub export fn isr5() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $5
        \\ jmp isr_common
    );
}

pub export fn isr6() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $6
        \\ jmp isr_common
    );
}

pub export fn isr7() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $7
        \\ jmp isr_common
    );
}

pub export fn isr8() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $8
        \\ jmp isr_common
    );
}

pub export fn isr9() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $9
        \\ jmp isr_common
    );
}

pub export fn isr10() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $10
        \\ jmp isr_common
    );
}

pub export fn isr11() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $11
        \\ jmp isr_common
    );
}

pub export fn isr12() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $12
        \\ jmp isr_common
    );
}

pub export fn isr13() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $13
        \\ jmp isr_common
    );
}

pub export fn isr14() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $14
        \\ jmp isr_common
    );
}

pub export fn isr15() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $15
        \\ jmp isr_common
    );
}

pub export fn isr16() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $16
        \\ jmp isr_common
    );
}

pub export fn isr17() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $17
        \\ jmp isr_common
    );
}

pub export fn isr18() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $18
        \\ jmp isr_common
    );
}

pub export fn isr19() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $19
        \\ jmp isr_common
    );
}

pub export fn isr20() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $20
        \\ jmp isr_common
    );
}

pub export fn isr21() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $21
        \\ jmp isr_common
    );
}

pub export fn isr22() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $22
        \\ jmp isr_common
    );
}

pub export fn isr23() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $23
        \\ jmp isr_common
    );
}

pub export fn isr24() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $24
        \\ jmp isr_common
    );
}

pub export fn isr25() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $25
        \\ jmp isr_common
    );
}

pub export fn isr26() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $26
        \\ jmp isr_common
    );
}

pub export fn isr27() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $27
        \\ jmp isr_common
    );
}

pub export fn isr28() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $28
        \\ jmp isr_common
    );
}

pub export fn isr29() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $29
        \\ jmp isr_common
    );
}
pub export fn isr30() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $30
        \\ jmp isr_common
    );
}

pub export fn isr31() void {
    asm volatile (
        \\ cli
        \\ push $0
        \\ push $31
        \\ jmp isr_common
    );
}
