const std = @import("std");
const Tuple = std.meta.Tuple;
const Allocator = std.mem.Allocator;
const Error = Allocator.Error;

pub const Node = struct {
    size: usize,
    next: ?*Node,
    const NodeSize = @sizeOf(?*Node);
    fn init(size: usize, next: ?*Node) Node {
        return Node{ .size = size, .next = next };
    }

    fn take(self: *Node, comptime T: type) Tuple(&.{ ?*Node, *T }) {
        const size = @sizeOf(T);
        const value_ptr = @intToPtr(*T, @ptrToInt(self));
        if (size < Node.NodeSize) {
            return .{ null, value_ptr };
        }
        const free_space = self.size - size;
        var next = self.next;
        const new_node = @intToPtr(*Node, @ptrToInt(self) + size);
        new_node.* = Node.init(free_space, null);
        new_node.next = next;

        return .{ new_node, value_ptr };
    }
};

const FreeList = @This();
heap_start: usize,
heap_size: usize,
head: ?*Node,

pub fn init(heap_start: usize, heap_size: usize) FreeList {
    var head = @intToPtr(*Node, heap_start);
    head.* = Node.init(heap_size, null);
    return FreeList{ .heap_start = heap_start, .heap_size = heap_size, .head = head };
}

pub fn alloc(self: *FreeList, comptime T: type, value: T) Error!*T {
    var prev: ?*Node = null;
    var node = self.head;
    var size: usize = @sizeOf(T);
    while (node) |n| {
        if (n.size >= size) {
            break;
        }
        prev = node;
        node = n.next;
    }

    var node_found = node orelse return Error.OutOfMemory;
    var split = node_found.take(T);
    const next_node = split[0];
    const addr = split[1];

    if (prev) |p| {
        if (next_node) |n| {
            p.next = n;
        } else {
            p.next = node_found.next;
        }
    } else {
        if (next_node) |n| {
            self.head = n;
        } else {
            self.head = node_found.next;
        }
    }

    addr.* = value;
    return addr;
}

pub fn free(self: *FreeList, size: usize) void {
    _ = size;
    _ = self;
}
