const std = @import("std");
const log = std.log.scoped(.address_space);
const MemoryRegion = @import("memmap.zig").MemoryRegion;
const paging = @import("arch").paging;
const PAGE_SIZE = paging.PAGE_SIZE;
const isPageAligned = paging.isPageAligned;
const Tree = @import("rbtree.zig").Tree(MemoryRegion, compareRegions);

fn compareRegions(a: MemoryRegion, b: MemoryRegion) bool {
    return a.size > b.size;
}

tree: Tree,
const Self = @This();
pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .tree = Tree.init(allocator),
    };
}

pub fn insert(self: *Self, val: MemoryRegion) !void {
    const matcher: struct {
        val: MemoryRegion,
        pub fn match(m: *const @This(), a: *const MemoryRegion) bool {
            return a.start == m.val.end() or a.end() == m.val.end();
        }
    } = .{ .val = val };

    if (self.tree.find(@TypeOf(matcher), matcher)) |node| {
        const start = @min(node.data.start, val.start);
        const end = start + node.data.size + val.size;
        node.data = MemoryRegion.init(start, end);
    } else {
        try self.tree.insert(val);
    }
}

pub fn allocate(self: *Self, size: usize) !MemoryRegion {
    const aligned_size = std.mem.alignForward(usize, size, PAGE_SIZE);
    const matcher: struct {
        size: usize,
        pub fn match(m: *const @This(), a: *const MemoryRegion) bool {
            std.debug.assert(isPageAligned(a.start));
            std.debug.assert(isPageAligned(a.end()));

            return (a.start + m.size) <= a.end();
        }
    } = .{ .size = aligned_size };

    const node = self.tree.find(@TypeOf(matcher), matcher) orelse return error.OutOfMemory;
    const alloc_end = node.data.start + size;
    const region = MemoryRegion.init(node.data.start, alloc_end);
    self.tree.delete(node);
    errdefer self.tree.insert(node.data) catch {};
    if (alloc_end != node.data.end()) {
        try self.insert(MemoryRegion.init(alloc_end, node.data.end() - alloc_end));
    }

    return region;
}

pub fn free(self: *Self, region: MemoryRegion) !void {
    try self.insert(region);
}
