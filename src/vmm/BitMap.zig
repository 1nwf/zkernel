const std = @import("std");
const PAGE_SIZE = @import("arch").paging.PAGE_SIZE;

const MemoryRegion = @import("memmap.zig").MemRegion;

pub fn BitMap(comptime size: usize) type {
    return struct {
        data: [size]usize,
        const Self = @This();
        const BITS_PER_ENTRY = @bitSizeOf(usize);
        pub fn init(reserved: []MemoryRegion) Self {
            var bitmap = Self{
                .data = [_]usize{0} ** size,
            };

            for (reserved) |region| {
                var start = std.mem.alignBackward(usize, region.start, PAGE_SIZE);
                const end = std.mem.alignForward(usize, region.end, PAGE_SIZE);
                while (start < end) : (start += PAGE_SIZE) {
                    bitmap.allocRegion(start) catch {};
                }
            }

            return bitmap;
        }
        pub fn allocRegion(self: *Self, addr: usize) !void {
            const bit_idx: usize = addr / PAGE_SIZE;
            try self.set(bit_idx);
        }

        pub fn alloc(self: *Self) !usize {
            for (&self.data, 0..) |*entry, idx| {
                if (entry.* == std.math.maxInt(usize)) continue;
                const bit_idx = @ctz(~entry.*);
                try self.set(bit_idx);
                return (bit_idx + (idx * BITS_PER_ENTRY)) * PAGE_SIZE;
            }
            return error.OutOfMemory;
        }

        pub fn free(self: *Self, addr: usize) void {
            const bit_idx = addr / PAGE_SIZE;
            self.clear(bit_idx);
        }

        pub fn set(self: *Self, idx: usize) !void {
            const entry = idx / BITS_PER_ENTRY;
            if (entry >= self.data.len) return error.OutOfMemory;
            self.data[entry] |= (@as(usize, 1) << @intCast(idx % BITS_PER_ENTRY));
        }

        pub fn clear(self: *Self, idx: usize) void {
            self.data[idx / BITS_PER_ENTRY] &= ~(@as(usize, 1) << @intCast(idx % BITS_PER_ENTRY));
        }
    };
}

test "init" {
    const expect = std.testing.expect;
    var reserved = [_]MemoryRegion{
        MemoryRegion.init(0, 0x1000),
        MemoryRegion.init(0x1000, 0x2000),
        MemoryRegion.init(0x2000, 0x3000),
        MemoryRegion.init(0x4000, 0x5000),
    };

    var bitmap = BitMap(1).init(&reserved);

    try expect(bitmap.data[0] == 0b10111);
}

test "alloc" {
    const expect = std.testing.expect;
    var reserved = [_]MemoryRegion{};

    var bitmap = BitMap(1).init(&reserved);

    comptime var i = 0;
    inline while (i < 64) : (i += 1) {
        _ = try bitmap.alloc();
    }

    try expect(bitmap.data[0] == std.math.maxInt(usize));
    try std.testing.expectError(error.OutOfMemory, bitmap.alloc());
}

test "free" {
    const expect = std.testing.expect;
    var reserved = [_]MemoryRegion{};

    var bitmap = BitMap(1).init(&reserved);

    const addr = try bitmap.alloc();
    try expect(bitmap.data[0] == 1);
    try expect(addr == 0);

    bitmap.free(addr);
    try expect(bitmap.data[0] == 0);

    const addrs = [_]usize{ try bitmap.alloc(), try bitmap.alloc(), try bitmap.alloc() };
    try std.testing.expectEqual([_]usize{ 0, PAGE_SIZE, PAGE_SIZE * 2 }, addrs);
    bitmap.free(addrs[1]);

    try expect(bitmap.data[0] == 0b101);
    try expect(try bitmap.alloc() == PAGE_SIZE);
    try expect(bitmap.data[0] == 0b111);
    bitmap.free(addrs[0]);
    try expect(bitmap.data[0] == 0b110);
    bitmap.free(addrs[1]);
    try expect(bitmap.data[0] == 0b100);
    bitmap.free(addrs[2]);
    try expect(bitmap.data[0] == 0);
}

test "allocRegion" {
    const expect = std.testing.expect;
    var reserved = [_]MemoryRegion{};

    var bitmap = BitMap(2).init(&reserved);

    const bit_index = (PAGE_SIZE * 64) * 2 - 1;
    try bitmap.allocRegion(bit_index);
    try expect(bitmap.data[1] == 1 << 63);

    bitmap.clear(127);
    try expect(bitmap.data[1] == 0);
}
