const UdpSocket = @import("UdpSocket.zig");
const std = @import("std");

pub const Socket = union(enum) {
    udp: UdpSocket,

    pub fn send(self: *Socket, data: anytype) !void {
        return switch (self.*) {
            .udp => |*u| u.send(data),
        };
    }

    pub fn recv(self: *Socket) ?[]u8 {
        return switch (self.*) {
            .udp => |*u| u.recv(),
        };
    }

    pub fn canRecv(self: *Socket) bool {
        return switch (self.*) {
            .udp => |*u| u.canRecv(),
        };
    }
    pub fn free(self: *Socket, data: []u8) void {
        return switch (self.*) {
            .udp => |*u| u.free(data),
        };
    }
};
