const std = @import("std");
const arch = @import("arch");
const writefn = @import("../drivers/vga.zig").write;
const process_scheduler = @import("../process/scheduler.zig");
const log = std.log;

const exit = @import("exit.zig").exit;

pub const Syscall = enum(u32) {
    Print = 0,
    Exit,
    Read,
    Yeild,
    fn fromInt(val: u32) ?@This() {
        return switch (val) {
            0...3 => @enumFromInt(val),
            else => null,
        };
    }
};

pub const syscall_int_handler = arch.interrupt_handler(syscall_handler);

// %eax -> system call number
// %ebx -> arg 1
// %ecx -> arg 2
// %edx -> arg 3
// %esi -> arg 4
// %edi -> arg 5
export fn syscall_handler(ctx: arch.thread.Context) usize {
    const num: u32 = ctx.eax;
    const arg1: u32 = ctx.ebx;
    const arg2: u32 = ctx.ecx;
    const arg3: u32 = ctx.edx;
    const arg4: u32 = ctx.esi;
    const arg5: u32 = ctx.edi;
    _ = arg2;
    _ = arg3;
    _ = arg4;
    _ = arg5;

    const syscall_num = Syscall.fromInt(num) orelse return 0;
    switch (syscall_num) {
        .Print => {
            if (arg1 != 0) {
                const fmt: *[]const u8 = @ptrFromInt(arg1);
                writefn("{s}", .{fmt.*});
            }
        },
        .Exit => exit(),
        .Read => {},
        .Yeild => return yeild(ctx),
    }

    return 0;
}

inline fn yeild(ctx: arch.thread.Context) usize {
    if (process_scheduler.run_next(ctx)) |next| {
        return @intFromPtr(next);
    }
    return 0;
}
