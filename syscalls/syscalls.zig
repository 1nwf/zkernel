pub const Syscall = enum(u32) {
    Print = 0,
    Exit,
    Read,
    Yeild,
    pub fn fromInt(val: u32) ?@This() {
        return switch (val) {
            0...3 => @enumFromInt(val),
            else => null,
        };
    }
};

pub const MessageType = enum(u32) {
    char,
};

pub const Message = struct {
    mtype: MessageType,
    msg: u32,
    pub fn init(msg_type: MessageType, msg: u32) Message {
        return .{
            .mtype = msg_type,
            .msg = msg,
        };
    }
};
