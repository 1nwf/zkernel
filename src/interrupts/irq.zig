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
pub export fn irq0() void {
    asm volatile (
        \\ cli
        \\ push $32
        \\ push $0
        \\ jmp irq_common
    );
}

pub export fn irq1() void {
    asm volatile (
        \\ cli
        \\ push $33
        \\ push $1
        \\ jmp irq_common
    );
}

pub export fn irq2() void {
    asm volatile (
        \\ cli
        \\ push $34
        \\ push $2
        \\ jmp irq_common
    );
}

pub export fn irq3() void {
    asm volatile (
        \\ cli
        \\ push $35
        \\ push $3
        \\ jmp irq_common
    );
}

pub export fn irq4() void {
    asm volatile (
        \\ cli
        \\ push $36
        \\ push $4
        \\ jmp irq_common
    );
}

pub export fn irq5() void {
    asm volatile (
        \\ cli
        \\ push $37
        \\ push $5
        \\ jmp irq_common
    );
}

pub export fn irq6() void {
    asm volatile (
        \\ cli
        \\ push $38
        \\ push $6
        \\ jmp irq_common
    );
}

pub export fn irq7() void {
    asm volatile (
        \\ cli
        \\ push $39
        \\ push $7
        \\ jmp irq_common
    );
}

pub export fn irq8() void {
    asm volatile (
        \\ cli
        \\ push $40
        \\ push $8
        \\ jmp irq_common
    );
}

pub export fn irq9() void {
    asm volatile (
        \\ cli
        \\ push $41
        \\ push $9
        \\ jmp irq_common
    );
}

pub export fn irq10() void {
    asm volatile (
        \\ cli
        \\ push $42
        \\ push $10
        \\ jmp irq_common
    );
}

pub export fn irq11() void {
    asm volatile (
        \\ cli
        \\ push $43
        \\ push $11
        \\ jmp irq_common
    );
}

pub export fn irq12() void {
    asm volatile (
        \\ cli
        \\ push $44
        \\ push $12
        \\ jmp irq_common
    );
}

pub export fn irq13() void {
    asm volatile (
        \\ cli
        \\ push $45
        \\ push $13
        \\ jmp irq_common
    );
}

pub export fn irq14() void {
    asm volatile (
        \\ cli
        \\ push $46
        \\ push $14
        \\ jmp irq_common
    );
}

pub export fn irq15() void {
    asm volatile (
        \\ cli
        \\ push $47
        \\ push $15
        \\ jmp irq_common
    );
}
