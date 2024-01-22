const std = @import("std");
const arch = @import("arch");
const writefn = @import("../drivers/vga.zig").write;
const scheduler = @import("../process/scheduler.zig");
const log = std.log;
const Syscall = @import("syscalls").Syscall;

const exit = @import("exit.zig").exit;

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
        .Read => {
            if (read(ctx, arg1)) |new_ctx| {
                return @intFromPtr(new_ctx);
            }
        },
        .Yeild => return yeild(ctx),
    }

    return 0;
}

inline fn yeild(ctx: arch.thread.Context) usize {
    if (scheduler.run_next(ctx)) |next| {
        return @intFromPtr(next);
    }
    return 0;
}

const keyboard = @import("../drivers/keyboard.zig");

fn read(ctx: arch.thread.Context, handle: u32) ?*arch.thread.Context {
    switch (handle) {
        1 => {
            var thread = scheduler.takeCurrentThread() orelse @panic("current thread is null");
            thread.context = ctx;
            keyboard.setListeningThread(thread);
            if (scheduler.run_next(ctx)) |new_ctx| {
                return new_ctx;
            } else {
                arch.halt();
            }
        },
        else => {
            log.info("invalid handle number", .{});
        },
    }

    return null;
}
