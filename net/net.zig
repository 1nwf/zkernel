pub const arp = @import("protocols/arp.zig");
pub const ethernet_frame = @import("ethernet_frame.zig");
pub const Nic = @import("Nic.zig");
pub const udp = @import("protocols/udp.zig");
pub const ip = @import("protocols/ip.zig");
pub const dhcp = @import("protocols/dhcp.zig");
pub const Interface = @import("iface.zig");

pub const UdpSocket = @import("socket/UdpSocket.zig");
pub const Socket = @import("socket/socket.zig").Socket;

pub usingnamespace @import("utils.zig");

pub var IFACE: Interface = undefined;
