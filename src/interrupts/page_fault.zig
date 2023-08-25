const std = @import("std");
const Context = @import("interrupts.zig").Context;

// NOTE: address that caused page fault is stored in the `cr2` register
pub export fn pageFaultHandler(ctx: Context) void {
    const cr2 = asm volatile (
        \\ mov %%cr2, %[cr2]
        : [cr2] "={eax}" (-> usize),
    );
    std.log.info("a page fault occured: {} {}", .{ ctx.int_num, cr2 });
}
