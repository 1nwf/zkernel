const MemMapEntry = @import("../../boot/mutliboot_header.zig").MemMapEntry;
const std = @import("std");
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
            return ListNode.init(start, self.size + other.size);
        }

        if (self_addr > other_addr) {
            self.next = other;
            return self;
        }

        other.next = self;
        return other;
    }
};

const AllocError = error{
    OutOfMem,
};

const PAGE_SIZE = 4096;
extern const kernel_start: usize;
extern const kernel_end: usize;

pub const BumpAllocator = struct {
    head: ?ListNodePtr = null,
    var prev: ?ListNodePtr = null;

    // TODO: dont override kernel code or kenrel stack
    pub fn init(memMap: []MemMapEntry) @This() {
        var allocator = @This(){};
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

    pub fn allocPage(self: *@This()) AllocError![*]u8 {
        if (self.head == null) {
            return AllocError.OutOfMem;
        }
        const head = self.head.?;
        std.debug.assert(head.size >= PAGE_SIZE);

        const next_node = ListNode.init(@intFromPtr(head) + PAGE_SIZE, head.size - PAGE_SIZE);
        self.head = next_node;
        return @ptrCast(head);
    }

    pub fn freePage(self: *@This(), addr: usize) void {
        if (self.head == null) {
            self.head = ListNode.init(addr, PAGE_SIZE);
            return;
        }
        self.head = self.head.?.appendNode(ListNode.init(addr, PAGE_SIZE));
    }

    pub fn print(self: *@This()) void {
        var temp = self.head;
        while (temp) |entry| {
            std.log.info("entry: 0x{x}", .{entry.size});
            temp = entry.next;
        }
    }
};
