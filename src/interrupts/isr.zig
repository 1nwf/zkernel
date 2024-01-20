const int = @import("interrupts.zig");
const writeln = @import("../drivers/vga.zig").writeln;
const arch = @import("arch");

export fn isr_handler(ctx: int.Context) void {
    const handler = int.interrupt_handlers[ctx.int_num];
    handler(ctx);
}

pub export fn isr_common() callconv(.Naked) void {
    asm volatile (
        \\ cli
        \\ pusha
        \\
        \\ call isr_handler
        \\
        \\ popa
        \\ add $8, %%esp
        \\ sti
        \\ iret
    );
}

pub const isr_handlers = blk: {
    var handlers: [32]*const fn () callconv(.C) void = [_]*const fn () callconv(.C) void{undefined} ** 32;
    for (0..handlers.len) |idx| {
        handlers[idx] = struct {
            fn handler() callconv(.C) void {
                asm volatile (
                    \\ cli
                    \\ push $0 
                    \\ push %[num]
                    \\ jmp isr_common
                    :
                    : [num] "i" (idx),
                );
            }
        }.handler;
    }
    break :blk handlers;
};
