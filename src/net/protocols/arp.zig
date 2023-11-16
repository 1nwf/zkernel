const std = @import("std");
const mem = std.mem;

pub const HardwareType = enum(u16) {
    Ethernet = 0x1,

    pub fn num_type(comptime self: @This()) type {
        return switch (self) {
            .Ethernet => u48,
        };
    }
};

pub const ProtocolType = enum(u16) {
    IPv4 = 0x800,
    IPv6 = 0x86dd,

    pub fn num_type(comptime self: @This()) type {
        return switch (self) {
            .IPv4 => u32,
            .IPv6 => u128,
        };
    }
};

pub fn Packet(comptime HT: HardwareType, comptime PT: ProtocolType) type {
    const ha_size = @bitSizeOf(HT.num_type()) / 8;
    const pa_size = @bitSizeOf(PT.num_type()) / 8;
    // const HA_TYPE = HT.num_type();
    // const PA_TYPE = PT.num_type();
    return extern struct {
        const Operation = enum(u16) { Request = 1, Response = 2 };
        htype: HardwareType align(1) = HT,
        ptype: ProtocolType align(1) = PT,
        hlen: u8 = ha_size, // hardware address length
        plen: u8 = pa_size, // protocol address length
        operation: Operation align(1),
        sha: [ha_size]u8 align(1), // sender hardware address
        spa: [pa_size]u8 align(1), // sender protocol address
        tha: [ha_size]u8 align(1), // target hardware address
        tpa: [pa_size]u8 align(1), // target protocol address

        const Self = @This();
        pub fn initRequest(sha: [ha_size]u8, spa: [pa_size]u8, tpa: [pa_size]u8) Self {
            return .{
                .sha = sha,
                .spa = spa,
                .tha = [_]u8{0} ** ha_size,
                .tpa = tpa,
                .operation = .Request,
            };
        }
    };
}
