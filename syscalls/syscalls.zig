pub const Syscall = enum(u32) {
    Print = 0,
    Exit,
    Read,
    Yeild,
    Socket,
    pub fn fromInt(val: u32) ?@This() {
        return switch (val) {
            0...4 => @enumFromInt(val),
            else => null,
        };
    }
};

pub const MessageType = enum(u32) {
    handle,
    char,
    err,
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

pub const Protocol = enum(u16) {
    Udp,
};

pub const CreateSocketOptions = struct {
    dest_port: u16,
    dest_ip: [4]u8,
    protocol: Protocol,
};
