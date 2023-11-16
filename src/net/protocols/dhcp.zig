const Udp = @import("udp.zig");
const std = @import("std");
const util = @import("../utils.zig");

const MAGIC_COOKIE: [4]u8 = .{ 99, 130, 83, 99 };

pub const Header = extern struct {
    const IpAddr = [4]u8;
    op: enum(u8) { Request = 1, Reply = 2 },
    htype: u8 = 1, // hardware type. 1 = ethernet
    hlen: u8 = 6, // header length
    hops: u8, // max hop count
    xid: u32 align(1),
    secs: u16 align(1),
    flags: u16 align(1),
    ciaddr: IpAddr, // client ip address
    yiaddr: IpAddr, // your ip address
    siaddr: IpAddr, // server ip address
    giaddr: IpAddr, // gateway ip address
    chaddr: [6]u8, // client hardware address
    pad: [10]u8 = [_]u8{0} ** 10,
    sname: [64]u8 = [_]u8{0} ** 64, // server name
    file: [128]u8 = [_]u8{0} ** 128,
    magic_cookie: [4]u8 = MAGIC_COOKIE,
};

pub const Options = extern struct {
    const OptionType = enum(u8) {
        MessageType = 53,
        SubnetMask,
    };

    const MessageType = enum(u8) {
        Discover = 1,
        Offer,
        Request,
        Decline,
        Ack,
        Nak,
        Release,
        Inform,
    };

    option_type: OptionType,
    length: u8,
    data: u8,
};

pub fn Packet(comptime options_len: u8) type {
    return extern struct {
        header: Header,
        options: [options_len]u8,
        end: u8 = 0xff,

        const Self = @This();
    };
}

const ClientId = extern struct {
    option: u8 = 61,
    length: u8,
    hw_type: u8,
    addr: [6]u8 align(1),
};

fn ParameterRequestList(comptime params: u8) type {
    return extern struct {
        option: u8 = 55,
        length: u8 = params,
        options: [params]u8,
    };
}

pub fn discoverPacket(mac_addr: [6]u8) Packet(18) {
    const header = Header{
        .op = .Request,
        .hops = 0,
        .xid = 1,
        .secs = 0,
        .flags = 0,
        .ciaddr = std.mem.zeroes([4]u8),
        .yiaddr = std.mem.zeroes([4]u8),
        .siaddr = std.mem.zeroes([4]u8),
        .giaddr = std.mem.zeroes([4]u8),
        .chaddr = mac_addr,
    };

    const client_id = ClientId{
        .length = 7,
        .hw_type = 1,
        .addr = mac_addr,
    };

    const params = ParameterRequestList(4){
        .options = [_]u8{ 1, 3, 6, 42 },
    };

    return Packet(18){
        .header = header,
        .options = std.mem.toBytes(Options{
            .option_type = .MessageType,
            .length = 1,
            .data = 1,
        }) ++ std.mem.toBytes(client_id) ++ std.mem.toBytes(params),
    };
}
