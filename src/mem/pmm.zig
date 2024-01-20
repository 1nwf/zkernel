const std = @import("std");
const MemMapEntry = @import("memmap.zig").MemMapEntry;
const BitMap = @import("BitMap.zig").BitMap;
const Allocator = std.mem.Allocator;
const MemRegion = @import("memmap.zig").MemoryRegion;
const PAGE_SIZE = @import("arch").paging.PAGE_SIZE;

const Self = @This();

bitmap: BitMap(null),
memory_regions: []MemRegion,
allocator: Allocator,

pub fn init(mem_map: []MemMapEntry, allocator: Allocator, reserved_regions: []const MemRegion) !Self {
    var free_mem = std.ArrayList(MemRegion).init(allocator);
    var size: usize = 0;
    for (mem_map) |mem| {
        if (mem.type != .Available) continue;
        var region = MemRegion.init(@intCast(mem.base_addr), @intCast(mem.len));
        try free_mem.append(region);
        size += region.size;
    }

    const bitmap_entries = std.mem.alignForward(usize, size, PAGE_SIZE * 8) / (PAGE_SIZE * 8);
    var bitmap = try BitMap(null).init(allocator, bitmap_entries);

    var pmm: Self = .{
        .bitmap = bitmap,
        .memory_regions = try free_mem.toOwnedSlice(),
        .allocator = allocator,
    };

    for (reserved_regions) |res| {
        try pmm.allocRegion(res.start, res.size);
    }

    return pmm;
}

pub fn allocRegion(self: *Self, addr: usize, size: usize) !void {
    var start_bit = self.getBitFromAddr(addr) orelse return;
    const end_bit = self.getBitFromAddr(addr + size) orelse return;
    while (start_bit < end_bit) : (start_bit += 1) {
        try self.bitmap.set(start_bit);
    }
}

pub fn allocN(self: *Self, n: usize) !usize {
    _ = self;
    _ = n;
}

pub fn alloc(self: *Self) !usize {
    var bit_idx = try self.bitmap.setFirstFree();
    return self.getAddrFromBit(bit_idx) orelse error.OutOfMemory;
}

pub fn free(self: *Self, addr: usize) void {
    const bit_index = self.getBitFromAddr(addr) orelse return;
    self.bitmap.clear(bit_index) catch @panic("bit_index out of range");
}

fn getAddrFromBit(self: *Self, bit_idx: usize) ?usize {
    var prev: usize = 0;
    for (self.memory_regions) |region| {
        const pages = region.size / PAGE_SIZE;
        var bit_end = prev + pages;
        if (bit_idx < bit_end) {
            const curr_idx = bit_idx - prev;
            const addr = region.start + (curr_idx * PAGE_SIZE);
            return addr;
        }
        prev = bit_end;
    }
    return null;
}

pub fn hasCapacity(self: *Self, n: usize) bool {
    return self.bitmap.hasCapacity(n);
}

fn getBitFromAddr(self: *Self, addr: usize) ?usize {
    var bit_index: usize = 0;
    for (self.memory_regions) |region| {
        if (addr < region.start or addr >= region.start + region.size) {
            bit_index += region.size / PAGE_SIZE;
            continue;
        }
        const bit = addr / PAGE_SIZE;
        return bit_index + bit;
    }
    return null;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.memory_regions);
    self.bitmap.deinit();
}

test "alloc" {
    const expect = std.testing.expect;
    var allocator = std.testing.allocator;
    var mem_map = [_]MemMapEntry{
        .{
            .base_addr = 0,
            .len = PAGE_SIZE * 20,
            .type = .Available,
        },
    };

    var pmm = try init(&mem_map, allocator, &.{});
    defer pmm.deinit();

    var i: usize = 0;
    while (i < 20) : (i += 1) {
        _ = try pmm.alloc();
    }

    try std.testing.expectError(error.OutOfMemory, pmm.alloc());
    try expect(pmm.bitmap.data.len == 3);
}

test "getBitFromAddr" {
    const expect = std.testing.expect;
    var allocator = std.testing.allocator;
    var mem_map = [_]MemMapEntry{
        .{
            .base_addr = 0,
            .len = PAGE_SIZE * 20,
            .type = .Available,
        },
    };

    var pmm = try init(&mem_map, allocator, &.{});
    defer pmm.deinit();

    var i: usize = 0;
    while (i < 20) : (i += 1) {
        try expect(pmm.getBitFromAddr(i * PAGE_SIZE) == i);
    }
}

test "getAddrFromBit" {
    const expect = std.testing.expect;
    var allocator = std.testing.allocator;
    var mem_map = [_]MemMapEntry{
        .{
            .base_addr = 0,
            .len = PAGE_SIZE * 20,
            .type = .Available,
        },
        .{
            .base_addr = PAGE_SIZE * 24,
            .len = PAGE_SIZE * 4,
            .type = .Available,
        },
        .{
            .base_addr = PAGE_SIZE * 28,
            .len = PAGE_SIZE * 4,
            .type = .Available,
        },
    };
    const addrs = blk: {
        var addrs = [_]usize{0} ** 28;
        var i: usize = 0;
        while (i < 28) : (i += 1) {
            if (i >= 24) {
                addrs[i] = (i + 4) * PAGE_SIZE;
            } else if (i >= 20) {
                addrs[i] = (i + 4) * PAGE_SIZE;
            } else {
                addrs[i] = i * PAGE_SIZE;
            }
        }
        break :blk addrs;
    };
    var pmm = try init(&mem_map, allocator, &.{});

    defer pmm.deinit();

    var i: usize = 0;
    while (i < 28) : (i += 1) {
        const addr = pmm.getAddrFromBit(i);
        try expect(addr == addrs[i]);
    }

    try expect(pmm.getAddrFromBit(100) == null);
}

test "allocRegions" {
    const expect = std.testing.expect;
    var allocator = std.testing.allocator;
    var mem_map = [_]MemMapEntry{
        .{
            .base_addr = 0,
            .len = PAGE_SIZE * 20,
            .type = .Available,
        },
    };

    var pmm = try init(&mem_map, allocator, &.{});
    defer pmm.deinit();

    var i: usize = 4;
    try pmm.allocRegion(PAGE_SIZE * i, PAGE_SIZE * 2);
    while (i < 2) : (i += 1) {
        try expect(pmm.bitmap.isSet(i));
    }
}
