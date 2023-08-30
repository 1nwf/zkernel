const std = @import("std");
const PAGE_SIZE = @import("arch").paging.PAGE_SIZE;
const Allocator = std.mem.Allocator;

const MemoryRegion = @import("memmap.zig").MemoryRegion;

pub fn BitMap(comptime size: ?usize) type {
    return struct {
        data: if (dynamic) []u8 else [size.?]u8,
        allocator: if (dynamic) Allocator else ?Allocator,
        const dynamic = size == null;
        const Self = @This();
        const BITS_PER_ENTRY = 8;
        pub fn init(allocator: if (dynamic) Allocator else ?Allocator, n: if (dynamic) usize else ?usize) !Self {
            var bitmap: Self = undefined;
            if (dynamic) {
                bitmap = Self{
                    .data = try allocator.alloc(u8, n),
                    .allocator = allocator,
                };
                @memset(bitmap.data, 0);
            } else {
                bitmap = Self{
                    .data = [_]u8{0} ** size.?,
                    .allocator = null,
                };
            }

            return bitmap;
        }

        pub fn setFirstFree(self: *Self) !usize {
            for (self.data, 0..) |entry, idx| {
                if (entry == std.math.maxInt(u8)) continue;
                const bit_idx = @ctz(~entry) + (idx * BITS_PER_ENTRY);
                try self.set(bit_idx);
                return bit_idx;
            }
            return error.OutOfMemory;
        }

        pub fn set(self: *Self, idx: usize) !void {
            const entry = idx / BITS_PER_ENTRY;
            if (entry >= self.data.len) return error.OutOfMemory;
            self.data[entry] |= (@as(u8, 1) << @intCast(idx % BITS_PER_ENTRY));
        }

        pub fn clear(self: *Self, idx: usize) void {
            self.data[idx / BITS_PER_ENTRY] &= ~(@as(u8, 1) << @intCast(idx % BITS_PER_ENTRY));
        }

        pub fn isSet(self: *Self, bit: usize) bool {
            const offset: u3 = @intCast(bit % BITS_PER_ENTRY);
            return ((self.data[bit / BITS_PER_ENTRY] >> offset) & 1) == 1;
        }

        pub fn deinit(self: *Self) void {
            if (dynamic) {
                self.allocator.free(self.data);
            }
        }
    };
}

test "init" {
    const expect = std.testing.expect;

    var bitmap = try BitMap(1).init(null, null);

    try expect(bitmap.data[0] == 0);
    try expect(bitmap.data.len == 1);
}

test "setFirstFree" {
    const expect = std.testing.expect;

    var bitmap = try BitMap(2).init(null, null);

    comptime var i = 0;
    inline while (i < 16) : (i += 1) {
        _ = try bitmap.setFirstFree();
    }

    try expect(bitmap.data[0] == std.math.maxInt(u8));
    try expect(bitmap.data[1] == std.math.maxInt(u8));
    try std.testing.expectError(error.OutOfMemory, bitmap.setFirstFree());
}

test "clear" {
    const expect = std.testing.expect;
    var bitmap = try BitMap(2).init(null, null);

    comptime var i = 0;
    inline while (i < 16) : (i += 1) {
        _ = try bitmap.setFirstFree();
        try expect(bitmap.isSet(i));
    }
    i -= 1;
    inline while (i >= 0) : (i -= 1) {
        bitmap.clear(i);
        try expect(!bitmap.isSet(i));
    }
}
