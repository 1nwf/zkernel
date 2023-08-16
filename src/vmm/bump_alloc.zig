const MemMapEntry = @import("../boot/mutliboot_header.zig").MemMapEntry;
const MemoryRegion = @import("memmap.zig").MemRegion;
const PAGE_SIZE = @import("arch").paging.PAGE_SIZE;
const std = @import("std");

const ListNodePtr = *allowzero ListNode;
const ListNode = struct {
    size: usize,
    next: ?ListNodePtr = null,

    fn init(addr: *anyopaque, size: usize) ListNodePtr {
        var node: ListNodePtr = @ptrCast(@alignCast(addr));
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
            const node = ListNode.init(@ptrFromInt(start), self.size + other.size);
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

pub const BumpAllocator = struct {
    head: ?ListNodePtr = null,
    reserved: []MemoryRegion,
    const Self = @This();

    // TODO: dont override kernel code or kenrel stack
    pub fn init(memMap: []MemMapEntry, reserved: []MemoryRegion) Self {
        var allocator = Self{
            .Reserved = reserved,
        };
        var prev: ?ListNodePtr = null;
        for (memMap) |entry| {
            if (entry.type != .Available or entry.length < PAGE_SIZE) continue;
            var base_addr = std.mem.alignForward(usize, @as(usize, @intCast(entry.base_addr)), PAGE_SIZE);
            var node = ListNode.init(base_addr, @intCast(entry.length));
            if (prev) |p| {
                p.next = node;
                prev = node;
            } else {
                allocator.head = node;
                prev = node;
            }
        }

        return allocator;
    }

    pub fn allocPage(self: *Self) AllocError![*]u8 {
        if (self.head == null) {
            return AllocError.OutOfMem;
        }
        const head = self.head.?;
        std.debug.assert(head.size >= PAGE_SIZE);

        const next_node = ListNode.init(@intFromPtr(head) + PAGE_SIZE, head.size - PAGE_SIZE);
        self.head = next_node;
        return @ptrCast(head);
    }

    pub fn freePage(self: *Self, addr: usize) void {
        if (self.head == null) {
            self.head = ListNode.init(addr, PAGE_SIZE);
            return;
        }
        self.head = self.head.?.appendNode(ListNode.init(addr, PAGE_SIZE));
    }

    pub fn print(self: *Self) void {
        var temp = self.head;
        while (temp) |entry| {
            std.log.info("entry: 0x{x}", .{entry.size});
            temp = entry.next;
        }
    }
};

test "ListNode.appendNode" {
    const expectEqual = std.testing.expectEqual;
    var buff: [3]ListNode = undefined;
    var node = ListNode.init(&buff[0], @sizeOf(ListNode));
    var node2 = ListNode.init(&buff[1], @sizeOf(ListNode));
    var node3 = ListNode.init(&buff[2], @sizeOf(ListNode));

    var head = node.appendNode(node3);
    try expectEqual(node, head);
    try expectEqual(head.next, node3);
    head = node.appendNode(node2);
    try expectEqual(node, head);
    try expectEqual(head.next, node3);
}
