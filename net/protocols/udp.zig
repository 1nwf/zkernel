pub fn Datagram(comptime T: type) type {
    return extern struct {
        src_port: u16 align(1),
        dest_port: u16 align(1),
        length: u16 align(1), // length of udp header + payload
        checksum: u16 align(1) = 0, // optional
        data: T align(1),

        const Self = @This();
        pub fn init(src_port: u16, dest_port: u16, data: T) Self {
            return .{
                .src_port = src_port,
                .dest_port = dest_port,
                .length = @as(u16, @bitSizeOf(Self) / 8),
                .data = data,
            };
        }
    };
}
