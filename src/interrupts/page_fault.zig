const std = @import("std");
const Context = @import("interrupts.zig").Context;
const arch = @import("arch");

// NOTE: address that caused page fault is stored in the `cr2` register
pub export fn pageFaultHandler(ctx: Context) void {
    _ = ctx;
    const cr2 = asm volatile (
        \\ mov %%cr2, %[cr2]
        : [cr2] "={eax}" (-> usize),
    );
    std.log.info("a page fault occured: 0x{x}", .{cr2});
    arch.halt();
}
