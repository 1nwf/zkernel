const std = @import("std");
const nic = @import("Nic.zig");

const udp = @import("protocols/udp.zig");
const utils = @import("utils.zig");
const Frame = @import("ethernet_frame.zig").Frame;
const ip = @import("protocols/ip.zig");
const Deque = @import("../utils/deque.zig").Deque;

const Self = @This();

const SocketOptions = struct {
    src_port: u16,
    dest_port: u16,
    dest_mac: [6]u8,
    src_mac: [6]u8,
    protocol: enum { Udp },
};

options: SocketOptions,
allocator: std.mem.Allocator,
recv_buffer: Deque([]u8, 10),

pub fn init(allocator: std.mem.Allocator, options: SocketOptions) !Self {
    return .{
        .options = options,
        .allocator = allocator,
        .recv_buffer = try Deque([]u8, 10).init(allocator),
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
        .source_ip = .{ 0, 0, 0, 0 },
        .dest_ip = .{ 0xff, 0xff, 0xff, 0xff },
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
    if (self.recv_buffer.isEmpty()) return null;
    return self.recv_buffer.popFront();

    // const bytes = nic.receive_packet() orelse return null;
    // const frame = utils.bigEndianToStruct(Frame(void), bytes);
    // if (frame.protocol != .Ipv4) return null;
    // const ip_packet = utils.bigEndianToStruct(ip.IpPacket(void), bytes[@offsetOf(@TypeOf(frame), "packet")..]);
    // std.log.info("ip: {}", .{ip_packet});
    // if (ip_packet.header.next_level_protocol != .Udp) return null;

    // const data_offset = @sizeOf(@TypeOf(frame)) + @offsetOf(@TypeOf(ip_packet), "data");
    // const datagram = utils.bigEndianToStruct(udp.Datagram(void), bytes[data_offset..]);
    // std.log.info("datagram: {}", .{datagram});

    // return bytes;
}
