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
