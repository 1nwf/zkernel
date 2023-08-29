const MemMapEntry = @import("../boot/mutliboot_header.zig").MemMapEntry;
const MemoryRegion = @import("memmap.zig").MemoryRegion;
const arch = @import("arch");
const PAGE_SIZE = arch.paging.PAGE_SIZE;
const PageDirectory = arch.paging.PageDirectory;
const std = @import("std");
const log = std.log.scoped(.frame_allocator);
pub const BitMap = @import("BitMap.zig").BitMap;

const ListNodePtr = *allowzero ListNode;
const ListNode = struct {
    size: usize,
    next: ?ListNodePtr = null,

    fn init(addr: usize, size: usize) ListNodePtr {
        var node: ListNodePtr = @ptrFromInt(addr);
        node.size = size;
        node.next = null;
        return node;
    }

    pub fn appendNode(self: ListNodePtr, other: ListNodePtr) ListNodePtr {
        const self_addr = @intFromPtr(self);
        const other_addr = @intFromPtr(other);

        // end is exclusive
        const self_end = self_addr + self.size;
        const other_end = other_addr + other.size;
        if (self_end == other_addr or other_end == self_addr) {
            const start = @min(self_addr, other_addr);
            const next1 = self.next;
            const next2 = other.next;
            const node = ListNode.init(start, self.size + other.size);
            if (next1) |n1| {
                if (next2) |n2| {
                    node.next = n1.appendNode(n2);
                } else {
                    node.next = n1;
                }
            } else if (next2) |n2| {
                node.next = n2;
            }
            return node;
        }

        if (self_addr < other_addr) {
            if (self.next) |next| {
                self.next = next.appendNode(other);
            } else {
                self.next = other;
            }
            return self;
        }

        if (other.next) |next| {
            other.next = next.appendNode(self);
        } else {
            other.next = self;
        }
        return other;
    }
};

const AllocError = error{
    OutOfMem,
};

extern const kernel_start: usize;
extern const kernel_end: usize;

// Free List
pub const FrameAllocator = struct {
    head: ?ListNodePtr = null,
    page_dir: *PageDirectory,
    const Self = @This();

    pub fn init(memMap: []MemMapEntry, reserved: []MemoryRegion, pg_dir: *PageDirectory) Self {
        var allocator = Self{
            .page_dir = pg_dir,
        };
        var prev: ?ListNodePtr = null;
        const appendNode = struct {
            fn appendNode(pmm: *FrameAllocator, node: ListNodePtr, prev_node: *?ListNodePtr, pgdir: *PageDirectory) void {
                if (prev_node.*) |p| {
                    p.next = node;
                    prev_node.* = node;
                } else {
                    pmm.head = node;
                    prev_node.* = node;
                }
                pgdir.mapPage(@intFromPtr(node), @intFromPtr(node));
            }
        }.appendNode;

        outer: for (memMap) |entry| {
            if (entry.type != .Available or entry.length < PAGE_SIZE) continue;
            const start = std.mem.alignForward(usize, @intCast(entry.base_addr), PAGE_SIZE);
            const end = std.mem.alignBackward(usize, @intCast(entry.base_addr + entry.length), PAGE_SIZE);
            for (reserved) |res| {
                const in = res.start >= start and res.end <= end;
                if (!in or res.start == start and res.end == end) continue;
                const first_start = start; // 4KIB Aligned
                const first_end = start + (res.start - start); // 4KIB aligned
                if (first_end - first_start != 0) {
                    var node = ListNode.init(first_start, first_end - first_start);
                    appendNode(&allocator, node, &prev, pg_dir);
                }

                const second_start = res.end; // 4KIB aligned
                const second_end = res.end + (end - res.end); // 4KIB aligned

                if (second_end - second_start != 0) {
                    var node = ListNode.init(second_start, second_end - second_start);
                    appendNode(&allocator, node, &prev, pg_dir);
                }
                continue :outer;
            }
            var node = ListNode.init(start, end - start);
            appendNode(&allocator, node, &prev, pg_dir);
        }
        return allocator;
    }

    pub fn allocPage(self: *Self) AllocError![*]u8 {
        if (self.head == null) {
            return AllocError.OutOfMem;
        }
        const head = self.head.?;
        std.debug.assert(head.size >= PAGE_SIZE);

        const next_ptr = @intFromPtr(head) + PAGE_SIZE;
        self.page_dir.mapPage(next_ptr, next_ptr);
        const next_node = ListNode.init(next_ptr, head.size - PAGE_SIZE);
        self.head = next_node;
        return @ptrCast(head);
    }

    pub fn freePage(self: *Self, addr: usize) void {
        if (self.head == null) {
            self.head = ListNode.init(addr, PAGE_SIZE);
            return;
        }
        self.page_dir.unmapPage(addr);
        self.head = self.head.?.appendNode(ListNode.init(addr, PAGE_SIZE));
    }

    pub fn print(self: *Self) void {
        var temp = self.head;
        while (temp) |entry| {
            std.log.info("addr: 0x{x} -- 0x{x}", .{ @intFromPtr(entry), @intFromPtr(entry) + entry.size });
            temp = entry.next;
        }
    }
};

test "ListNode.appendNode" {
    const expectEqual = std.testing.expectEqual;
    var buff: [3]ListNode = undefined;
    var node = ListNode.init(@intFromPtr(&buff[0]), @sizeOf(ListNode));
    var node2 = ListNode.init(@intFromPtr(&buff[1]), @sizeOf(ListNode));
    var node3 = ListNode.init(@intFromPtr(&buff[2]), @sizeOf(ListNode));

    var head = node.appendNode(node3);
    try expectEqual(node, head);
    try expectEqual(head.next, node3);
    head = node.appendNode(node2);
    try expectEqual(node, head);
    try expectEqual(head.next, node3);
}

test "FrameAllocator.init" {
    const expecEqual = std.testing.expectEqual;
    var alloc = std.testing.allocator;

    const block = try alloc.alignedAlloc(u8, PAGE_SIZE, PAGE_SIZE * 3);
    defer alloc.free(block);

    var reserved = [_]MemoryRegion{
        MemoryRegion.init(@intFromPtr(&block[PAGE_SIZE]), @intFromPtr(&block[PAGE_SIZE]) + PAGE_SIZE),
    };

    var mem = [_]MemMapEntry{
        .{
            .type = .Available,
            .size = @sizeOf(MemMapEntry),
            .base_addr = @intFromPtr(&block[0]),
            .length = PAGE_SIZE * 3,
        },
    };

    var pg_dir: PageDirectory align(PAGE_SIZE) = PageDirectory.init();
    var frame_allocator = FrameAllocator.init(&mem, &reserved, &pg_dir);
    try expecEqual(@intFromPtr(frame_allocator.head.?), @intFromPtr(&block[0]));
    try expecEqual(frame_allocator.head.?.size, PAGE_SIZE);
    const next = frame_allocator.head.?.next.?;
    try expecEqual(@intFromPtr(next), @intFromPtr(&block[PAGE_SIZE * 2]));
    try expecEqual(next.size, PAGE_SIZE);
}

test "allocPage" {
    const expecEqual = std.testing.expectEqual;
    var alloc = std.testing.allocator;

    const block = try alloc.alignedAlloc(u8, PAGE_SIZE, PAGE_SIZE * 3);
    defer alloc.free(block);

    var reserved = [_]MemoryRegion{
        MemoryRegion.init(@intFromPtr(&block[PAGE_SIZE]), @intFromPtr(&block[PAGE_SIZE]) + PAGE_SIZE),
    };

    var mem = [_]MemMapEntry{
        .{
            .type = .Available,
            .size = @sizeOf(MemMapEntry),
            .base_addr = @intFromPtr(&block[0]),
            .length = PAGE_SIZE * 3,
        },
    };

    var pg_dir: PageDirectory align(PAGE_SIZE) = PageDirectory.init();
    var frame_alloc = FrameAllocator.init(&mem, &reserved, &pg_dir);
    try expecEqual(@intFromPtr(frame_alloc.head.?), @intFromPtr(&block[0]));
    try expecEqual(frame_alloc.head.?.size, PAGE_SIZE);
    const next = frame_alloc.head.?.next.?;
    try expecEqual(@intFromPtr(next), @intFromPtr(&block[PAGE_SIZE * 2]));
    try expecEqual(next.size, PAGE_SIZE);
}
