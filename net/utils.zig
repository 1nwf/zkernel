const std = @import("std");
const mem = std.mem;
const log = std.log.info;

pub fn swapFields(value: anytype) [@sizeOf(@TypeOf(value))]u8 {
    var v = value;
    inline for (std.meta.fields(@TypeOf(value))) |f| {
        switch (@typeInfo(f.type)) {
            .Enum => |info| {
                const enum_val = @intFromEnum(@field(v, f.name));
                var val_ptr = &@field(v, f.name);
                mem.writeIntBig(info.tag_type, mem.asBytes(val_ptr), enum_val);
            },
            .Int => {
                @field(v, f.name) = mem.nativeToBig(f.type, @field(v, f.name));
            },
            .Struct => {
                const bytes = swapFields(@field(v, f.name));
                @field(v, f.name) = mem.bytesToValue(f.type, &bytes);
            },
            .Array => {
                // const arr_type = @typeInfo(f.type).Array;
                // for (0..arr_type.len) |idx| {
                //     data[curr_idx + idx] = mem.nativeToBig(arr_type.child, @field(value, f.name)[idx]);
                // }
            },
            else => @compileError("unsupported type: " ++ @typeName(f.type)),
        }
    }

    // std.debug.assert(@sizeOf(@TypeOf(value)) == @bitSizeOf(@TypeOf(v)) / 8);
    return mem.toBytes(v);
}

pub fn structToBigEndian(value: anytype) [@bitSizeOf(@TypeOf(value)) / 8]u8 {
    const t = @typeInfo(@TypeOf(value));
    if (t != .Struct) @compileError("must pass in struct");

    var data: [@bitSizeOf(@TypeOf(value)) / 8]u8 = undefined;
    @memset(&data, 0);
    var curr_idx: usize = 0;
    inline for (std.meta.fields(@TypeOf(value))) |f| {
        const size = @bitSizeOf(f.type) / 8;
        switch (@typeInfo(f.type)) {
            .Enum => {
                const field_data = @intFromEnum(@field(value, f.name));
                mem.writeIntSliceBig(@TypeOf(field_data), data[curr_idx .. curr_idx + size], field_data);
            },
            .Int => {
                mem.writeIntSliceBig(f.type, data[curr_idx .. curr_idx + size], @field(value, f.name));
            },
            .Struct => {
                @memcpy(data[curr_idx .. curr_idx + size], structToBigEndian(@field(value, f.name))[0..]);
            },
            .Array => {
                const arr_type = @typeInfo(f.type).Array;
                for (0..arr_type.len) |idx| {
                    data[curr_idx + idx] = mem.nativeToBig(arr_type.child, @field(value, f.name)[idx]);
                }
            },
            else => @compileError("unsupported field " ++ @typeName(f.type)),
        }
        curr_idx += size;
    }

    return data;
}

// pub fn bigEndianToStruct(comptime T: type, buffer: []u8) T {
//     var value = std.mem.bytesToValue(T, buffer[0..@sizeOf(T)]);
//     try byteSwapStruct(T, &value);
//     return value;
// }

pub fn bigEndianAsStruct(comptime T: type, buffer: []u8) *T {
    var value = std.mem.bytesAsValue(T, buffer[0..@sizeOf(T)]);
    try byteSwapStruct(T, value);
    return value;
}

pub fn byteSwapStruct(comptime T: type, value: *T) !void {
    inline for (std.meta.fields(T)) |f| {
        switch (@typeInfo(f.type)) {
            .Int => {
                @field(value, f.name) = @byteSwap(@field(value, f.name));
            },
            .Enum => {
                const int_val = @intFromEnum(@field(value, f.name));
                @field(value, f.name) = @enumFromInt(@byteSwap(int_val));
            },
            .Struct => {
                var ptr = @field(value, f.name);
                try byteSwapStruct(f.type, &ptr);
                @field(value, f.name) = ptr;
            },
            .Array => {
                const arr_type = @typeInfo(f.type).Array;
                for (0..arr_type.len) |idx| {
                    @field(value, f.name)[idx] = @byteSwap(@field(value, f.name)[idx]);
                }
            },
            .Void => {},
            else => @compileError("invalid field in struct " ++ @typeName(f.type)),
        }
    }
}

pub fn calculateChecksum(data: []const u8) u16 {
    var sum: usize = 0;
    var idx: usize = 0;
    while (idx <= data.len - 2) : (idx += 2) {
        const value = mem.readIntSlice(u16, data[idx .. idx + 2], .Big);
        sum += value;
    }

    if (idx != data.len) { // add skipped byte
        sum += data[data.len - 1];
    }

    while ((sum >> 16) != 0) {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    return ~(@as(u16, @intCast(sum)));
}

test "ip header checksum" {
    const ip = @import("protocols/ip.zig");
    const ip_header = ip.Header{
        .tos = 0xC0,
        .total_length = 315,
        .ident = 0,
        .flags_and_fragment_offset = 0,
        .ttl = 64,
        .next_level_protocol = .Udp,
        .checksum = 0,
        .source_ip = .{ 0, 0, 0, 0 },
        .dest_ip = .{ 0xff, 0xff, 0xff, 0xff },
    };
    const bytes = swapFields(ip_header);
    const checksum = calculateChecksum(&bytes);

    try std.testing.expectEqual(checksum, 0x78f3);
}
