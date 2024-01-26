const std = @import("std");
const nic = @import("Nic.zig");

const udp = @import("protocols/udp.zig");
const utils = @import("utils.zig");
const Frame = @import("ethernet_frame.zig").Frame;
const ip = @import("protocols/ip.zig");

const Self = @This();

pub const Protocol = enum { Udp };

const SocketOptions = struct {
    src_port: u16,
    dest_port: u16,
    //
    dest_ip: [4]u8,
    src_ip: [4]u8,
    //
    dest_mac: [6]u8,
    src_mac: [6]u8,
    protocol: Protocol,
};

options: SocketOptions,
allocator: std.mem.Allocator,
rx_buffer: std.ArrayList([]u8),

pub fn init(allocator: std.mem.Allocator, options: SocketOptions) Self {
    return .{
        .options = options,
        .allocator = allocator,
        .rx_buffer = std.ArrayList([]u8).init(allocator),
    };
}

fn make_packet(self: Self, data: anytype) ![]u8 {
    const datagram = udp.Datagram(@TypeOf(data)).init(self.options.src_port, self.options.dest_port, data);
    const total_length = (@bitSizeOf(ip.Header) / 8) + (@bitSizeOf(@TypeOf(datagram)) / 8);
    var ip_header = ip.Header{
        .total_length = total_length,
        .tos = 0xC0,
        .ident = 0,
        .flags_and_fragment_offset = 0,
        .ttl = 64,
        .next_level_protocol = .Udp,
        .checksum = 0,
        .source_ip = self.options.src_ip,
        .dest_ip = self.options.dest_ip,
    };
    ip_header.calcChecksum();

    const ip_packet = ip.IpPacket(@TypeOf(datagram)).init(ip_header, datagram);
    var frame = Frame(@TypeOf(ip_packet)).init(self.options.dest_mac, self.options.src_mac, .Ipv4, ip_packet);
    const value = utils.swapFields(frame);
    var bytes = try self.allocator.alloc(u8, value.len);
    @memcpy(bytes, &value);
    return bytes;
}

pub fn send(self: *Self, data: anytype) !void {
    const bytes = try self.make_packet(data);
    defer self.allocator.free(bytes);
    try nic.transmit_packet(bytes);
}

pub fn recv(self: *Self) ?[]u8 {
    if (self.rx_buffer.items.len == 0) {
        return null;
    }
    return self.rx_buffer.pop();
}

pub fn process(self: *Self, data: []u8) void {
    var buff = self.allocator.alloc(u8, data.len) catch @panic("alloc failed");
    @memcpy(buff, data);
    self.rx_buffer.insert(0, buff) catch @panic("insert failed");
}

pub fn accepts(self: *Self, src_port: usize, dest_port: usize) bool {
    return self.options.dest_port == src_port and self.options.src_port == dest_port;
}

pub fn free(self: *Self, slice: []u8) void {
    self.allocator.free(slice);
}
