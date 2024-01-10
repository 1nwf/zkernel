const std = @import("std");
const PAGE_SIZE = @import("arch").paging.PAGE_SIZE;
const Allocator = std.mem.Allocator;

const MemoryRegion = @import("memmap.zig").MemoryRegion;

pub fn BitMap(comptime size: ?usize) type {
    return struct {
        const EntryType = u8;
        const BITS_PER_ENTRY = @bitSizeOf(EntryType);
        const dynamic = size == null;
        const Self = @This();

        data: if (dynamic) []EntryType else [size.?]EntryType,
        allocator: if (dynamic) Allocator else ?Allocator,
        free_bits: usize = if (size) |c| c * BITS_PER_ENTRY else 0,
        pub fn init(allocator: if (dynamic) Allocator else ?Allocator, n: if (dynamic) usize else ?usize) !Self {
            var bitmap: Self = undefined;
            if (dynamic) {
                bitmap = Self{
                    .data = try allocator.alloc(EntryType, n),
                    .allocator = allocator,
                    .free_bits = n * BITS_PER_ENTRY,
                };
                @memset(bitmap.data, 0);
            } else {
                bitmap = Self{
                    .data = [_]EntryType{0} ** size.?,
                    .allocator = null,
                };
            }

            return bitmap;
        }

        pub fn setFirstFree(self: *Self) !usize {
            if (self.free_bits == 0) return error.OutOfMemory;
            for (self.data, 0..) |entry, idx| {
                if (entry == std.math.maxInt(EntryType)) continue;
                const bit_idx = @ctz(~entry) + (idx * BITS_PER_ENTRY);
                try self.set(bit_idx);
                return bit_idx;
            }

            unreachable;
        }

        pub fn hasCapacity(self: *Self, n: usize) bool {
            return self.free_bits >= n;
        }

        // TODO
        pub fn setContiguous(self: *Self, n: usize) !usize {
            if (self.free_bits < n) return error.OutOfMemory;
            unreachable;
        }

        pub fn set(self: *Self, idx: usize) !void {
            const entry = idx / BITS_PER_ENTRY;
            if (entry >= self.data.len) return error.InvalidEntry;
            self.free_bits -= 1;
            self.data[entry] |= (@as(EntryType, 1) << @intCast(idx % BITS_PER_ENTRY));
        }

        pub fn clear(self: *Self, idx: usize) !void {
            const entry = idx / BITS_PER_ENTRY;
            if (entry >= self.data.len) return error.InvalidEntry;
            self.free_bits += 1;
            self.data[idx / BITS_PER_ENTRY] &= ~(@as(EntryType, 1) << @intCast(idx % BITS_PER_ENTRY));
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

    const bitmap = try BitMap(1).init(null, null);

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
        try bitmap.clear(i);
        try expect(!bitmap.isSet(i));
    }
}
