const std = @import("std");
const udp = @import("protocols/udp.zig");
const ip = @import("protocols/ip.zig");
const eth_frame = @import("ethernet_frame.zig");
const utils = @import("utils.zig");

ptr: *anyopaque,
mac_address: [6]u8,
vtable: *const VTable,
const Self = @This();

pub const VTable = struct {
    transmit_packet: *const fn (ctx: *anyopaque, addr: u32, len: u32) anyerror!void,
    receive_packet: *const fn (ctx: *anyopaque) ?[]u8,
};

pub fn transmit_packet(self: *Self, value: anytype) anyerror!void {
    const bytes = utils.swapFields(value);
    return self.vtable.transmit_packet(self.ptr, @intFromPtr(&bytes), bytes.len);
}

pub fn receive_packet(self: *Self) ?[]u8 {
    return self.vtable.receive_packet(self.ptr);
}

pub fn send_arp(self: *Self, packet: anytype, dest_mac_addr: [6]u8) !?[]u8 {
    const frame = eth_frame.Frame(@TypeOf(packet)).init(dest_mac_addr, self.mac_address, .Arp, packet);
    // const bytes = utils.structToBigEndian(frame);
    try self.transmit_packet(frame);
    return self.receive_packet();
}

pub fn udp_packet(self: *Self, comptime T: type, datagram: udp.Datagram(T), src_ip: [4]u8, dest_ip: [4]u8) !void {
    const total_length: u16 = (@bitSizeOf(ip.Header) / 8) + (@bitSizeOf(@TypeOf(datagram)) / 8);
    const ip_header = ip.Header{
        .total_length = total_length,
        .tos = 0,
        .ident = 0,
        .flags_and_fragment_offset = 0,
        .ttl = 10,
        .next_level_protocol = .Udp,
        .checksum = 0,
        .source_ip = src_ip,
        .dest_ip = dest_ip,
    };

    const target_mac = [_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
    const ip_packet = ip.IpPacket(@TypeOf(datagram)).init(ip_header, datagram);
    const frame = eth_frame.Frame(@TypeOf(ip_packet)).init(target_mac, self.mac_address, .Ipv4, ip_packet);
    try self.transmit_packet(frame);
}
