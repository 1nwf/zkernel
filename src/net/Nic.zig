const std = @import("std");
const udp = @import("protocols/udp.zig");
const ip = @import("protocols/ip.zig");
const eth_frame = @import("ethernet_frame.zig");
const utils = @import("utils.zig");

const dhcp = @import("protocols/dhcp.zig");

const Socket = @import("socket.zig");

ptr: *anyopaque,
mac_address: [6]u8,
vtable: *const VTable,
const Self = @This();

pub const VTable = struct {
    transmit_packet: *const fn (ctx: *anyopaque, addr: u32, len: u32) anyerror!void,
    receive_packet: *const fn (ctx: *anyopaque) ?[]u8,
};

var nic: Self = undefined;

pub fn transmit_packet(bytes: []const u8) anyerror!void {
    return nic.vtable.transmit_packet(nic.ptr, @intFromPtr(bytes.ptr), bytes.len);
}

pub fn receive_packet() ?[]u8 {
    return nic.vtable.receive_packet(nic.ptr);
}

pub fn send_arp(self: *Self, packet: anytype, dest_mac_addr: [6]u8) !?[]u8 {
    const frame = eth_frame.Frame(@TypeOf(packet)).init(dest_mac_addr, self.mac_address, .Arp, packet);
    const bytes = utils.structToBigEndian(frame);
    try self.transmit_packet(&bytes);
    return self.receive_packet();
}

pub fn init(ptr: *anyopaque, vtable: *const VTable, mac_address: [6]u8) *Self {
    nic = .{ .ptr = ptr, .vtable = vtable, .mac_address = mac_address };
    return &nic;
}

// get ip, dns, and router gateway through dhcp
pub fn dhcp_init(self: *Self, allocator: std.mem.Allocator) !void {
    var s = try Socket.init(allocator, .{
        .src_port = 68,
        .dest_port = 67,
        .dest_mac = .{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff },
        .src_mac = self.mac_address,
        .protocol = .Udp,
    });

    s.send(dhcp.discoverPacket(self.mac_address)) catch {};
    _ = s.recv();
}

pub fn handle_packet_recv() void {
    const bytes = receive_packet() orelse return;
    const frame = utils.bigEndianToStruct(eth_frame.Frame(void), bytes);
    std.log.info("frame: {}", .{frame});
    switch (frame.protocol) {
        .Ipv4 => {
            const ip_packet = utils.bigEndianToStruct(ip.IpPacket(void), bytes[@sizeOf(@TypeOf(frame))..]);
            const data = bytes[@sizeOf(@TypeOf(frame)) + @sizeOf(@TypeOf(ip_packet)) ..];
            handle_ip_packet_recv(ip_packet, data);
        },
        .Arp => {},
    }
}

fn handle_ip_packet_recv(packet: ip.IpPacket(void), data: []u8) void {
    std.log.info("ip packet: {}", .{packet});
    switch (packet.header.next_level_protocol) {
        .Udp => {
            const datagram = utils.bigEndianToStruct(udp.Datagram(void), data);
            const bytes = data[@sizeOf(@TypeOf(datagram))..];
            _ = bytes;
        },
        else => @panic("not yet supported"),
    }
}
