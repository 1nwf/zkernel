const std = @import("std");
const log = std.log;
const utils = @import("utils.zig");
const Nic = @import("Nic.zig");
const Protocol = Socket.Protocol;
const ip = @import("protocols/ip.zig");
const udp = @import("protocols/udp.zig");
const eth = @import("ethernet_frame.zig");
const dhcp = @import("protocols/dhcp.zig");

const Socket = @import("socket/socket.zig").Socket;
const UdpSocket = @import("socket/UdpSocket.zig");
const SockI = @import("socket/socket.zig");

nic: *Nic,
allocator: std.mem.Allocator,
sockets: std.ArrayList(Socket),

ip_addr: [4]u8 = std.mem.zeroes([4]u8),
router: [4]u8 = std.mem.zeroes([4]u8),
dns_addr: [4]u8 = std.mem.zeroes([4]u8),

const Self = @This();

pub fn init(allocator: std.mem.Allocator, nic: *Nic) !Self {
    return Self{
        .nic = nic,
        .sockets = std.ArrayList(Socket).init(allocator),
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
            self.process_udp(packet.header.source_ip, datagram);
        },
        else => @panic("not yet supported"),
    }
}

pub fn process_udp(self: *Self, src_ip: [4]u8, datagram: *udp.Datagram(void)) void {
    var data: []u8 = @as([*]u8, @ptrCast(&datagram.data))[0 .. datagram.length - 8]; // 8 is the sie of the datagram header
    for (self.sockets.items) |*socket| {
        switch (socket.*) {
            .udp => |*s| {
                if (s.accepts(src_ip, datagram.src_port, datagram.dest_port)) {
                    s.process(data) catch {};
                    break;
                }
            },
        }
    }
}

pub fn dhcp_init(self: *Self, sleepFn: *const fn (ms: usize) void) !void {
    const udp_socket = UdpSocket.init(.{
        .src_port = 68,
        .dest_port = 67,
        .dest_mac = eth.BROADCAST_ADDR,
        .dest_ip = ip.BROADCAST_ADDR,
        .src_ip = .{ 0, 0, 0, 0 },
        .src_mac = self.nic.mac_address,
    }, self.allocator);

    var socket = try self.createSocket(.{ .udp = udp_socket });

    try socket.send(dhcp.discoverPacket(self.nic.mac_address));
    if (!socket.canRecv()) {
        sleepFn(500);
    }

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

    // socket.options.src_ip = ip_addr;
    try socket.send(dhcp.makeRequest(self.nic.mac_address, ip_addr, dhcp_id));

    if (!socket.canRecv()) {
        sleepFn(500);
    }

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

pub fn createSocket(self: *Self, s: Socket) !*Socket {
    try self.sockets.append(s);
    return &self.sockets.items[self.sockets.items.len - 1];
}
