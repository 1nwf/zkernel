const Context = @import("interrupts.zig").Context;
const syscalls = @import("../syscalls/syscalls.zig");
const std = @import("std");
const arch = @import("arch");

pub export fn int_handler() void {
    syscalls.syscall_handler();
    asm volatile ("iret");
}
