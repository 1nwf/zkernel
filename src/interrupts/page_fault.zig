const std = @import("std");
const arch = @import("arch");

// NOTE: address that caused page fault is stored in the `cr2` register

pub const page_fault_interrupt_handler = arch.interrupt_handler(pageFaultHandler);
export fn pageFaultHandler(ctx: arch.thread.Context) usize {
    _ = ctx;
    const cr2 = asm volatile (
        \\ mov %%cr2, %[cr2]
        : [cr2] "={eax}" (-> usize),
    );
    std.log.info("a page fault occured: 0x{x}", .{cr2});

    while (true) {
        asm volatile (
            \\  cli
            \\  hlt
        );
    }
    return 0;
}
