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
                    bitmap.allocRegion(start);
                }
            }

            return bitmap;
        }
        pub fn allocRegion(self: *Self, addr: usize) void {
            const bit_idx: usize = addr / PAGE_SIZE;
            self.data[bit_idx / BITS_PER_ENTRY] |= (@as(usize, 1) << @intCast(bit_idx));
        }
    };
}

pub fn alloc() void {}
pub fn free() void {}

test {
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
