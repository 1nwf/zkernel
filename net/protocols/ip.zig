const std = @import("std");
const utils = @import("../utils.zig");

pub const IpNextHeaderProtocols = enum(u8) {
    Icmp = 1,
    Tcp = 6,
    Udp = 17,
};

pub const Header = extern struct {
    // length of ip header in 32 bit increments
    version_and_header_length: u8 = (4 << 4) | @bitSizeOf(@This()) / 32,
    // version: u4 = 4, // always 4
    tos: u8,
    // length of whole packet including payload
    total_length: u16 align(1),
    // identification number. used to identify related packets that are fragmented
    ident: u16 align(1),
    // flags and fragment offset of the payload from the original packet, measured as a multiple of 8 bytes.
    flags_and_fragment_offset: u16 align(1),
    /// time to live. number of router hops allowed
    ttl: u8,
    next_level_protocol: IpNextHeaderProtocols,
    checksum: u16 align(1),
    source_ip: [4]u8,
    dest_ip: [4]u8,
    // options: ?[]u8 = null,  // optional

    pub fn calcChecksum(self: *Header) void {
        self.checksum = 0;
        const bytes = utils.swapFields(self.*);
        self.checksum = utils.calculateChecksum(&bytes);
    }
};

pub fn IpPacket(comptime T: type) type {
    return extern struct {
        header: Header align(1),
        data: T align(1),

        const Self = @This();
        pub fn init(header: Header, data: T) Self {
            return .{
                .header = header,
                .data = data,
            };
        }
    };
}
