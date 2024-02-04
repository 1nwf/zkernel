const std = @import("std");
const nic = @import("../Nic.zig");
const utils = @import("../utils.zig");
const udp = @import("../protocols/udp.zig");
const ip = @import("../protocols/ip.zig");
const eth = @import("../ethernet_frame.zig");

const Self = @This();
const Options = struct {
    dest_ip: [4]u8,
    dest_port: u16,
    dest_mac: [6]u8,

    src_port: u16,
    src_ip: [4]u8,
    src_mac: [6]u8,

    pub fn init(
        dest_ip: [4]u8,
        dest_port: u16,
        dest_mac: [6]u8,
        src_port: u16,
        src_ip: [4]u8,
        src_mac: [6]u8,
    ) Options {
        return .{
            .dest_ip = dest_ip,
            .dest_port = dest_port,
            .dest_mac = dest_mac,
            .src_port = src_port,
            .src_ip = src_ip,
            .src_mac = src_mac,
        };
    }
};

options: Options,
allocator: std.mem.Allocator,
rx_buffer: std.ArrayList([]u8),

pub fn init(options: Options, allocator: std.mem.Allocator) Self {
    return .{
        .options = options,
        .rx_buffer = std.ArrayList([]u8).init(allocator),
        .allocator = allocator,
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
    var frame = eth.Frame(@TypeOf(ip_packet)).init(self.options.dest_mac, self.options.src_mac, .Ipv4, ip_packet);
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

pub fn canRecv(self: *Self) bool {
    return self.rx_buffer.items.len != 0;
}

pub fn free(self: *Self, slice: []u8) void {
    self.allocator.free(slice);
}

pub fn recv(self: *Self) ?[]u8 {
    return self.rx_buffer.getLastOrNull();
}

pub fn process(self: *Self, data: []u8) !void {
    var buff = try self.allocator.alloc(u8, data.len);
    @memcpy(buff, data);
    try self.rx_buffer.append(buff);
}

pub fn accepts(self: *const Self, src_ip: [4]u8, src_port: u16, dest_port: u16) bool {
    return (std.mem.eql(u8, &self.options.dest_ip, &ip.BROADCAST_ADDR) or std.mem.eql(u8, &self.options.dest_ip, &src_ip)) and
        self.options.src_port == dest_port and
        self.options.dest_port == src_port;
}
