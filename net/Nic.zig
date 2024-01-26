const std = @import("std");
const log = std.log;
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

var nic: Self = undefined;

pub const VTable = struct {
    transmit_packet: *const fn (ctx: *anyopaque, addr: u32, len: u32) anyerror!void,
    receive_packet: *const fn (ctx: *anyopaque) ?[]u8,
};

pub fn transmit_packet(bytes: []const u8) anyerror!void {
    return nic.vtable.transmit_packet(nic.ptr, @intFromPtr(bytes.ptr), bytes.len);
}

pub fn receive_packet(self: *Self) ?[]u8 {
    return self.vtable.receive_packet(self.ptr);
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
