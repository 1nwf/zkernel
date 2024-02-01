const std = @import("std");

pub usingnamespace @import("write.zig");
pub usingnamespace @import("exit.zig");

const syscalls = @import("syscalls");
const Syscall = syscalls.Syscall;
const Message = syscalls.Message;
const MessageType = syscalls.MessageType;

pub fn yeild() void {
    asm volatile (
        \\ int $48
        :
        : [_] "{eax}" (Syscall.Yeild),
    );
}

pub fn read(handle: u32) Message {
    var mtype: MessageType = undefined;
    var msg: u32 = undefined;
    asm volatile (
        \\ int $48
        : [mtype] "={eax}" (mtype),
          [msg] "={ebx}" (msg),
        : [_] "{eax}" (Syscall.Read),
          [_] "{ebx}" (handle),
    );

    return .{
        .mtype = mtype,
        .msg = msg,
    };
}

pub const CreateSocketOptions = syscalls.CreateSocketOptions;
pub fn socket(options: CreateSocketOptions) !usize {
    var arg1: u32 = @intCast(@intFromEnum(options.protocol));
    arg1 |= (@as(u32, (@intCast(options.dest_port))) << 16);

    var mtype: MessageType = undefined;
    var msg: u32 = undefined;

    const dest_ip: *const u32 = @alignCast(@ptrCast(&options.dest_ip));

    asm volatile (
        \\ int $48
        : [mtype] "={eax}" (mtype),
          [msg] "={ebx}" (msg),
        : [_] "{eax}" (Syscall.Socket),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (dest_ip.*),
    );

    if (mtype == .err) {
        return error.SyscallErr;
    }
    return msg;
}
