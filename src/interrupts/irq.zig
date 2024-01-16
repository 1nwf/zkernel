const writeln = @import("../drivers/vga.zig").writeln;
const write = @import("../drivers/vga.zig").write;
const int = @import("interrupts.zig");
const Context = @import("interrupts.zig").Context;
const sendEoi = @import("pic.zig").sendEoi;

export fn irq_handler(ctx: Context) void {
    const handler = int.interrupt_handlers[ctx.err_code];
    handler(ctx);
    sendEoi(ctx.int_num);
}

export fn irq_common() callconv(.Naked) void {
    asm volatile (
        \\ cli
        \\ pusha
        \\
        \\ call irq_handler
        \\
        \\ popa
        \\ add $8, %%esp
        \\ sti
        // removes CS, EIP, EFLAGS, SS, and ESP from the stack
        \\ iret 
    );
}

pub const irq_handlers = blk: {
    var handlers: [16]*const fn () callconv(.C) void = [_]*const fn () callconv(.C) void{undefined} ** 16;
    for (0..handlers.len) |idx| {
        handlers[idx] = struct {
            fn handler() callconv(.C) void {
                asm volatile (
                    \\ cli
                    \\ push %[n1] 
                    \\ push %[n2]
                    \\ jmp irq_common
                    :
                    : [n1] "i" (idx + 32),
                      [n2] "i" (idx),
                );
            }
        }.handler;
    }
    break :blk handlers;
};
