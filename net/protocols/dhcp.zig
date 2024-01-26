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

const MessageType = enum(u8) {
    discover = 1,
    offer,
    request,
    decline,
    ack,
    nak,
    release,
    inform,
};

const OptionType = enum(u8) {
    message_type = 53,
    subnet_mask = 1,
    dhcp_server_id = 54,
    router = 3,
    dns_addr = 6,
    ip_lease_time = 51,
    requested_ip_addr = 50,
    max_size = 57,
    host_name = 12,

    param_request_list = 55,

    end = 0xff,
};

pub fn OptionHeader(comptime T: type) type {
    return extern struct {
        option_type: OptionType,
        length: u8 = @sizeOf(T),
        value: T align(1),

        const Self = @This();
        pub fn init(option_type: OptionType, value: T) Self {
            return .{ .option_type = option_type, .value = value };
        }
    };
}

pub const Options = union(OptionType) {
    message_type: MessageType,
    dhcp_server_id: [4]u8,
    subnet_mask: [4]u8,
    router: [4]u8,
    dns_addr: [4]u8,
    ip_lease_time: u32,
    requested_ip_addr: [4]u8,
    host_name: [4]u8, // limit to 4 for now
    max_size: u16,
    // param list could contain more values. size limit is to avoid dynamic allocation
    param_request_list: [4]u8,
    end: void,
};

const Packet = extern struct {
    header: Header,
    options: [50]u8, // limit to 50 for now
    end: u8 = 0xff,
    const Self = @This();
};

fn ParameterRequestList(comptime params: u8) type {
    return extern struct {
        option_type: u8 = 55,
        length: u8 = params,
        options: [params]u8 align(1),
    };
}

pub fn readOptions(allocator: std.mem.Allocator, data: []u8) ![]Options {
    var idx: usize = 0;
    var options = std.ArrayList(Options).init(allocator);
    while (idx < data.len) {
        const option_type: OptionType = @enumFromInt(data[idx]);
        const length = data[idx + 1];
        switch (option_type) {
            .message_type => {
                const msg_type: MessageType = @enumFromInt(data[idx + 2]); // skip len byte
                try options.append(Options{ .message_type = msg_type });
            },
            .subnet_mask => {
                var value: [4]u8 = undefined;
                @memcpy(&value, data[idx + 2 .. idx + 2 + 4]);
                try options.append(Options{ .subnet_mask = value });
            },
            .dhcp_server_id => {
                var value: [4]u8 = undefined;
                @memcpy(&value, data[idx + 2 .. idx + 2 + 4]);
                try options.append(Options{ .dhcp_server_id = value });
            },
            .router => {
                var value: [4]u8 = undefined;
                @memcpy(&value, data[idx + 2 .. idx + 2 + 4]);
                try options.append(Options{ .router = value });
            },
            .dns_addr => {
                var value: [4]u8 = undefined;
                @memcpy(&value, data[idx + 2 .. idx + 2 + 4]);
                try options.append(Options{ .dns_addr = value });
            },
            .ip_lease_time => {
                const value = std.mem.readIntSliceBig(u32, data[idx + 2 .. idx + 2 + 4]);
                try options.append(Options{ .ip_lease_time = value });
            },
            .end => break,
            else => @panic("todo"),
        }
        idx += 2 + length;
    }

    return try options.toOwnedSlice();
}

pub fn optionsToBytes(options: []const Options) [50]u8 {
    if (options.len > 50) @panic("options exceed max len 50");
    var bytes: [50]u8 = std.mem.zeroes([50]u8);
    var idx: usize = 0;
    for (options) |val| {
        switch (val) {
            .message_type => |t| {
                const value = std.mem.toBytes(OptionHeader(MessageType).init(val, t));
                @memcpy(bytes[idx .. idx + @sizeOf(@TypeOf(value))], &value);
                idx += 3;
            },
            .dhcp_server_id, .requested_ip_addr, .host_name, .param_request_list => |data| {
                const value = std.mem.toBytes(OptionHeader([4]u8).init(val, data));
                @memcpy(bytes[idx .. idx + @sizeOf(@TypeOf(value))], &value);
                idx += 6;
            },
            .max_size => |size| {
                const value = std.mem.toBytes(OptionHeader(u16).init(val, size));
                @memcpy(bytes[idx .. idx + @sizeOf(@TypeOf(value))], &value);
                idx += 6; // actual size is 4 but we add 2 bytes of padding
            },
            else => @panic("todo"),
        }
    }

    return bytes;
}

pub fn discoverPacket(mac_addr: [6]u8) Packet {
    const header = Header{
        .op = .Request,
        .hops = 0,
        .xid = 0,
        .secs = 1,
        .flags = 0x0000,
        .ciaddr = std.mem.zeroes([4]u8),
        .yiaddr = std.mem.zeroes([4]u8),
        .siaddr = std.mem.zeroes([4]u8),
        .giaddr = std.mem.zeroes([4]u8),
        .chaddr = mac_addr,
    };

    const options = [_]Options{
        .{ .message_type = .discover },
        .{ .max_size = std.mem.nativeToBig(u16, 1024) },
        .{ .host_name = "test".* },
        .{ .param_request_list = .{ 1, 3, 6, 0 } },
    };

    return .{
        .header = header,
        .options = optionsToBytes(&options),
    };
}

pub fn makeRequest(mac_addr: [6]u8, ip_addr: [4]u8, dhcp_id: [4]u8) Packet {
    const header = Header{
        .op = .Request,
        .hops = 0,
        .xid = 0,
        .secs = 1,
        .flags = 0x0000,
        .ciaddr = std.mem.zeroes([4]u8),
        .yiaddr = std.mem.zeroes([4]u8),
        .siaddr = std.mem.zeroes([4]u8),
        .giaddr = std.mem.zeroes([4]u8),
        .chaddr = mac_addr,
    };

    const options = [_]Options{
        .{ .message_type = .request },
        .{ .dhcp_server_id = dhcp_id },
        .{ .requested_ip_addr = ip_addr },
    };

    return Packet{
        .header = header,
        .options = optionsToBytes(&options),
    };
}
