const std = @import("std");
const log = std.log;
const utils = @import("utils.zig");
const Nic = @import("Nic.zig");
const Socket = @import("socket.zig");
const Protocol = Socket.Protocol;
const ip = @import("protocols/ip.zig");
const udp = @import("protocols/udp.zig");
const eth = @import("ethernet_frame.zig");
const dhcp = @import("protocols/dhcp.zig");

nic: *Nic,
allocator: std.mem.Allocator,
sockets: std.AutoHashMap(Protocol, std.ArrayList(Socket)),

ip_addr: [4]u8 = std.mem.zeroes([4]u8),
router: [4]u8 = std.mem.zeroes([4]u8),
dns_addr: [4]u8 = std.mem.zeroes([4]u8),

const Self = @This();

pub fn init(allocator: std.mem.Allocator, nic: *Nic) Self {
    return Self{
        .nic = nic,
        .sockets = std.AutoHashMap(Protocol, std.ArrayList(Socket)).init(allocator),
        .allocator = allocator,
    };
}

pub fn proecssEthernetFrame(self: *Self) void {
    const data = self.nic.receive_packet() orelse return;
    const frame = utils.bigEndianAsStruct(eth.Frame(void), data);
    switch (frame.protocol) {
        .Ipv4 => {
            const packet: *ip.IpPacket(void) = @ptrCast(&frame.packet);
            try utils.byteSwapStruct(ip.IpPacket(void), packet);
            self.process_ip(packet);
        },
        .Arp => {},
    }
}

pub fn process_ip(self: *Self, packet: *ip.IpPacket(void)) void {
    switch (packet.header.next_level_protocol) {
        .Udp => {
            const datagram: *udp.Datagram(void) = @ptrCast(&packet.data);
            try utils.byteSwapStruct(udp.Datagram(void), datagram);
            self.process_udp(datagram);
        },
        else => @panic("not yet supported"),
    }
}

pub fn process_udp(self: *Self, datagram: *udp.Datagram(void)) void {
    var data: []u8 = @as([*]u8, @ptrCast(&datagram.data))[0 .. datagram.length - 8]; // 8 is the sie of the datagram header
    if (self.sockets.get(.Udp)) |sockets| {
        for (sockets.items) |*s| {
            if (s.accepts(datagram.src_port, datagram.dest_port)) s.process(data);
        }
    }
}

pub fn dhcp_init(self: *Self) !void {
    var arr = try self.sockets.getOrPut(.Udp);
    if (!arr.found_existing) {
        arr.value_ptr.* = std.ArrayList(Socket).init(self.allocator);
    }
    try arr.value_ptr.append(Socket.init(self.allocator, .{
        .src_port = 68,
        .dest_port = 67,
        .dest_mac = .{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff },
        .dest_ip = .{ 0xff, 0xff, 0xff, 0xff },
        .src_ip = .{ 0, 0, 0, 0 },
        .src_mac = self.nic.mac_address,
        .protocol = .Udp,
    }));

    var socket = &arr.value_ptr.items[arr.value_ptr.items.len - 1];
    socket.send(dhcp.discoverPacket(self.nic.mac_address)) catch {};

    const data = socket.recv() orelse @panic("recv is empty");
    defer socket.free(data);

    const ip_addr = utils.bigEndianAsStruct(dhcp.Header, data).yiaddr;
    self.ip_addr = ip_addr;
    const d = try dhcp.readOptions(self.allocator, data[@sizeOf(dhcp.Header)..]);
    var dhcp_id: [4]u8 = undefined;
    for (d) |item| {
        switch (item) {
            .dhcp_server_id => |val| dhcp_id = val,
            else => {},
        }
    }

    socket.options.src_ip = ip_addr;
    try socket.send(dhcp.makeRequest(self.nic.mac_address, ip_addr, dhcp_id));

    const ack = socket.recv() orelse @panic("recv is empty");
    defer socket.free(ack);

    const ack_options = try dhcp.readOptions(self.allocator, ack[@sizeOf(dhcp.Header)..]);
    for (ack_options) |val| {
        switch (val) {
            .message_type => |msg| {
                if (msg != .ack) @panic("todo");
            },
            .dns_addr => |addr| {
                self.dns_addr = addr;
            },
            .router => |addr| {
                self.router = addr;
            },
            else => {},
        }
    }
    self.ip_addr = ip_addr;
}
