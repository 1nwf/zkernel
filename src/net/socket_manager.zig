const std = @import("std");
const Socket = @import("socket.zig");

var socket_manager: std.ArayList(Socket) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    socket_manager = std.ArrayList(Socket).init(allocator);
}
