const std = @import("std");
const mem = std.mem;

pub const Protocol = enum(u16) {
    Arp = 0x806,
    Ipv4 = 0x800,
};

pub fn Frame(comptime T: type) type {
    return extern struct {
        dest_mac: [6]u8,
        src_mac: [6]u8,
        protocol: Protocol align(1),
        packet: T align(1),
        const Self = @This();
        pub fn init(dest_mac: [6]u8, src_mac: [6]u8, protocol: Protocol, packet: T) Self {
            return .{
                .dest_mac = dest_mac,
                .src_mac = src_mac,
                .protocol = protocol,
                .packet = packet,
            };
        }
    };
}
