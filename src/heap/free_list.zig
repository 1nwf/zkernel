const std = @import("std");
const Tuple = std.meta.Tuple;
const Allocator = std.mem.Allocator;
const Error = Allocator.Error;
const vga = @import("../drivers/vga.zig");

pub const Node = struct {
    size: usize,
    next: ?*Node,
    const NodeSize = @sizeOf(Node);
    fn init(size: usize, next: ?*Node) Node {
        return Node{ .size = size, .next = next };
    }

    fn take(self: *Node, comptime T: type) Tuple(&.{ ?*Node, *T }) {
        // adjust the size to make sure it fits a List Node
        const size = @max(@sizeOf(T), Node.NodeSize);
        const value_ptr: *T = @ptrCast(self);
        if (self.size < size) {
            return .{ null, value_ptr };
        }
        const free_space = self.size - size;
        const next = self.next;
        const new_node: *Node = @ptrFromInt(self.address() + size);
        new_node.* = Node.init(free_space, null);
        new_node.next = next;

        return .{ new_node, value_ptr };
    }

    inline fn address(self: *Node) usize {
        return @intFromPtr(self);
    }

    inline fn end_address(self: *Node) usize {
        return self.address() + self.size;
    }

    fn insert(self: *Node, node: *Node) *Node {
        if (self.end_address() == node.address()) {
            self.size += node.size;
            return self;
        } else if (node.end_address() == self.address()) {
            node.size += self.size;
            return node;
        } else if (self.address() < node.address()) {
            node.next = self.next;
            self.next = node;
            return self;
        } else {
            node.next = self;
            return node;
        }
    }
};

const FreeList = @This();
heap_start: usize,
heap_size: usize,
head: ?*Node,

pub fn init(heap_start: usize, heap_size: usize) FreeList {
    const head: *Node = @ptrFromInt(heap_start);
    head.* = Node.init(heap_size, null);
    return FreeList{ .heap_start = heap_start, .heap_size = heap_size, .head = head };
}

pub fn alloc(self: *FreeList, comptime T: type, value: T) Error!*T {
    var prev: ?*Node = null;
    var node = self.head;
    const size: usize = @max(Node.NodeSize, @sizeOf(T));
    while (node) |n| {
        if (n.size >= size) {
            break;
        }
        prev = node;
        node = n.next;
    }

    var node_found = node orelse return Error.OutOfMemory;
    const split = node_found.take(T);
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

pub fn free(self: *FreeList, ptr: anytype) void {
    // size is guaranteed to be at least the size of a list Node
    const size = @max(@sizeOf(@TypeOf(ptr.*)), Node.NodeSize);
    const node: *Node = @ptrCast(ptr);
    node.* = Node.init(size, null);
    self.insert(node);
}

fn insert(self: *FreeList, node: *Node) void {
    var prev: ?*Node = null;
    if (self.head) |head| {
        var curr_node: ?*Node = head;
        while (curr_node) |n| {
            if (n.address() > node.address()) {
                break;
            }
            prev = n;
            curr_node = n.next;
        }

        if (prev) |p| {
            _ = p.insert(node);
        } else {
            self.head = node.insert(head);
        }
    } else {
        self.head = node;
    }
}

pub fn nodes(self: *FreeList) void {
    var node = self.head;
    vga.writeln("nodes------------", .{});
    while (node) |n| {
        vga.writeln("{*} @ {}", .{ n, n });
        node = n.next;
    }
    vga.writeln("--------------", .{});
}
