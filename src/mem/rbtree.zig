const std = @import("std");
const Allocator = std.mem.Allocator;

const Color = enum { red, black };

pub fn Node(
    comptime T: type,
    comptime compareFn: fn (a: T, b: T) bool,
) type {
    return struct {
        data: T,
        children: [2]?*Self,
        color: Color,
        parent: ?*Self = null,
        const Self = @This();
        const Position = enum(u8) { left = 0, right };

        pub fn init(value: T, color: Color) Self {
            return .{
                .data = value,
                .children = .{ null, null },
                .color = color,
            };
        }

        fn compare(self: *const Self, other: T) bool {
            return compareFn(self.data, other);
        }

        fn leftChild(self: *Self) ?*Self {
            return self.children[0];
        }

        fn rightChild(self: *Self) ?*Self {
            return self.children[1];
        }

        fn rotateRight(self: *Self) *Self {
            var left = self.leftChild() orelse self;
            self.children[0] = left.rightChild();
            left.children[1] = self;

            if (self.parent) |parent| {
                parent.children[@intFromEnum(self.position())] = left;
            }

            left.parent = self.parent;
            self.parent = left;

            return left;
        }

        fn rotateLeft(self: *Self) *Self {
            var right = self.rightChild() orelse self;
            self.children[1] = right.leftChild();
            right.children[0] = self;

            if (self.parent) |parent| {
                parent.children[@intFromEnum(self.position())] = right;
            }

            right.parent = self.parent;
            self.parent = right;

            return right;
        }

        fn position(self: *Self) Position {
            if (self.parent) |p| {
                return if (p.children[1] == self) .right else .left;
            }
            return .left;
        }

        fn sibling(self: *Self) ?*Self {
            const pos = @intFromEnum(self.position());
            if (self.parent) |parent| {
                return parent.children[1 - pos];
            }
            return null;
        }

        fn isLeaf(self: *Self) bool {
            self.leftChild() == null and self.rightChild() == null;
        }

        fn minChild(self: *Self) *Self {
            var node = self.leftChild() orelse return self;
            while (node.leftChild()) |left| {
                node = left;
            }

            return node;
        }
    };
}

// red black tree
// Properties:
//  1. new nodes must be red
//  2. must be a binary tree
//  3. root is black
//  4. every leaf node is black
//  5. in all paths, there should be an equal number of black nodes

pub fn Tree(
    comptime T: type,
    comptime compareFn: fn (a: T, b: T) bool,
) type {
    return struct {
        const NodeType = Node(T, compareFn);
        const Self = @This();
        head: ?*NodeType,
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return .{
                .head = null,
                .allocator = allocator,
            };
        }

        pub fn insert(self: *Self, value: T) !void {
            var head = self.head orelse {
                self.head = try self.createNode(value, .black);
                return;
            };

            var node = try self.createNode(value, .red);
            var current: ?*NodeType = head;
            var prev: *NodeType = undefined;
            var position: u8 = undefined;
            while (current) |c| {
                position = @intFromBool(compareFn(node.data, c.data));
                current = c.children[position];
                prev = c;
            }

            prev.children[position] = node;
            node.parent = prev;
            self.balanceTree(node);
        }

        fn rotate(self: *Self, node: *NodeType, position: NodeType.Position) void {
            var new_head = if (position == .right) node.rotateRight() else node.rotateLeft();
            if (node == self.head) {
                self.head = new_head;
            }
        }

        fn balanceTree(self: *Self, node: *NodeType) void {
            var current = node;

            while (current.parent) |parent| {
                if (parent.color == .black) return;
                // parent is red. violated rb tree property
                // grandparent must be black
                // to resolve this, we need to see wether the current node's uncle is red or black

                var uncle = parent.sibling();
                var grandparent = parent.parent.?;
                const parent_pos = parent.position();
                const pos = current.position();
                // Case 1: P is red and U is black or null
                if (uncle == null or uncle.?.color == .black) {
                    // Case 1.1 P is a right child of G and K is a right child of P
                    // do left rotation at G that makes G the new sibling of K.
                    // Change the color of S to red and P to black

                    if (parent_pos == .right) {
                        // Case 1.2 P is a right child of G and K is a left child of P
                        // do right rotation at P. then do same steps as in Case 1.1
                        if (pos == .left) {
                            current.color = .black;
                            self.rotate(parent, .right);
                        } else {
                            parent.color = .black;
                        }
                        self.rotate(grandparent, .left);
                        if (grandparent != self.head) grandparent.color = .red;
                    } else {
                        // Case 1.3 P is a left child of G and K is a left child of P
                        if (pos == .right) {
                            self.rotate(parent, .left);
                            current.color = .black;
                        } else {
                            parent.color = .black;
                        }
                        self.rotate(grandparent, .right);
                        if (grandparent != self.head) grandparent.color = .red;
                    }
                } else {
                    // Case 2: P and U are both red
                    // flip the color of nodes, P, U, and G. P and U become black. G becomes Red
                    uncle.?.color = .black;
                    parent.color = .black;
                    if (grandparent != self.head) grandparent.color = .red;
                }
                current = grandparent;
            }
        }

        fn createNode(self: *Self, value: T, color: Color) !*NodeType {
            var node = try self.allocator.create(NodeType);
            node.* = NodeType.init(value, color);
            return node;
        }

        // finds the leftMost node that satisfies the matcher
        pub fn find(self: *Self, comptime matcher: fn (value: T) bool) ?*NodeType {
            var node = self.head;
            var prev: ?*NodeType = null;
            while (node) |n| {
                if (matcher(n.data)) {
                    prev = n;
                    node = n.leftChild();
                } else {
                    node = n.rightChild();
                }
            }

            return prev;
        }

        fn transplant(self: *Self, a: *NodeType, b: ?*NodeType) void {
            if (a.parent) |parent| {
                switch (a.position()) {
                    .left => parent.children[0] = b,
                    .right => parent.children[1] = b,
                }
                a.parent = null;
            } else {
                self.head = b;
            }

            var node = b orelse return;
            node.parent = a.parent;
            if (node == a.leftChild()) {
                a.children[0] = null;
            } else if (node == a.rightChild()) {
                a.children[1] = null;
            }
        }

        pub fn delete(self: *Self, node: *NodeType) void {
            var left = node.leftChild();
            var right = node.rightChild();
            if (left != null and right != null) {
                var min_child = right.?.minChild();
                node.data = min_child.data;
                self.delete(min_child);
                return;
            }
            // node has zero or one child

            // if the tree only has one child, the node's color must be black and the child's color must be red
            // in this case, remove the node and set the child's color to black
            if (left != null or right != null) {
                var child = left orelse right.?;
                self.transplant(node, child);
                child.color = .black;
                self.destroyNode(node);
                return;
            }

            // if node is red with no children, just remove it.
            if (node.color == .red) {
                self.transplant(node, null);
                self.destroyNode(node);
                return;
            }
            // double black case. node is black and both its children are null
            self.fixDoubleBlack(node);
        }

        fn fixDoubleBlack(self: *Self, node: *NodeType) void {
            const color = struct {
                fn color(node_: ?*NodeType) Color {
                    return if (node_) |n| return n.color else .black;
                }
            }.color;

            var current = node;
            while (current.parent) |parent| {
                var sibling = current.sibling() orelse @panic("node must have a sibling");
                var sleft = sibling.leftChild();
                var sright = sibling.rightChild();
                var rightc = color(sright);
                var leftc = color(sleft);
                if (parent.color == .red and sibling.color == .black and leftc == .black and rightc == .black) {
                    sibling.color = .red;
                    parent.color = .black;
                    break;
                } else if (sibling.color == .black and rightc == .red) {
                    self.rotate(parent, current.position());
                    sibling.color = parent.color;
                    parent.color = .black;
                    sright.?.color = .black;
                    break;
                } else if (sibling.color == .black and leftc == .black and rightc == .black) {
                    sibling.color = .red;
                    current = parent;
                } else if (sibling.color == .black and leftc == .red and parent.color == .black and rightc == .black) {
                    self.rotate(sibling, .left);
                    sleft.?.color = .black;
                    sibling.color = .red;
                } else if (parent.color == .black and sibling.color == .red and leftc == .black and rightc == .black) {
                    self.rotate(parent, current.position());
                    sibling.color = .black;
                    parent.color = .red;
                } else {
                    @panic("invalid case in fixDoubleBlack");
                }
            }

            self.transplant(node, null);
            self.destroyNode(node);
        }

        pub fn destroyNode(self: *Self, node: ?*NodeType) void {
            var root = node orelse return;
            if (root.children[0]) |left| {
                self.destroyNode(left);
            }
            if (root.children[1]) |right| {
                self.destroyNode(right);
            }

            self.allocator.destroy(root);
        }

        fn deinit(self: *Self) void {
            self.destroyNode(self.head);
        }
    };
}

fn compare(a: usize, b: usize) bool {
    return a > b;
}

test "insertion" {
    var allocator = std.testing.allocator;
    const expectEq = std.testing.expectEqual;
    var tree = Tree(usize, compare).init(allocator);
    defer tree.deinit();

    try tree.insert(3);
    try tree.insert(2);
    try tree.insert(1);

    //      3            2
    //    2      ->    1  3
    //  1

    var head = tree.head.?;
    var left = head.leftChild().?;
    var right = head.rightChild().?;

    try expectEq(.{ head.data, head.color }, .{ 2, .black });
    try expectEq(.{ left.data, left.color }, .{ 1, .red });
    try expectEq(.{ right.data, right.color }, .{ 3, .red });
}

test "insertion2" {
    var allocator = std.testing.allocator;
    const expectEq = std.testing.expectEqual;
    var tree = Tree(usize, compare).init(allocator);
    defer tree.deinit();

    //      12             3            3             3               3                   3
    //   3     25  -->  1    12 -->  1    12   -->  1   12    -->  1    12       -->  1      15
    // 1     15                             25            25               15               12  25
    //                                                      15               25

    try tree.insert(12);
    try tree.insert(3);
    try tree.insert(1);
    try tree.insert(25);
    try tree.insert(15);

    const head = tree.head.?;
    const right = head.rightChild().?;
    const left = head.leftChild().?;

    const lr = left.rightChild();
    const ll = left.leftChild();

    const rr = right.rightChild().?;
    const rl = right.leftChild().?;

    const rrl = rr.leftChild();
    const rrr = rr.rightChild();

    try expectEq(.{ head.data, head.color }, .{ 3, .black });
    try expectEq(.{ right.data, right.color }, .{ 15, .black });
    try expectEq(.{ rr.data, rr.color }, .{ 25, .red });
    try expectEq(.{ rl.data, rl.color }, .{ 12, .red });

    try expectEq(.{ left.data, left.color }, .{ 1, .black });
    try expectEq(left.leftChild(), null);
    try expectEq(left.rightChild(), null);

    try expectEq(rrr, null);
    try expectEq(rrl, null);
    try expectEq(lr, null);
    try expectEq(ll, null);
}

test "insertion3" {
    var allocator = std.testing.allocator;
    const expectEq = std.testing.expectEqual;
    var tree = Tree(usize, compare).init(allocator);
    defer tree.deinit();

    //    61
    // 52    85
    //          93

    try tree.insert(61);
    try tree.insert(52);
    try tree.insert(85);
    try tree.insert(93);

    const head = tree.head.?;
    const r = head.rightChild().?;
    const l = head.leftChild().?;
    const rr = r.rightChild().?;

    try expectEq(.{ head.data, head.color }, .{ 61, .black });
    try expectEq(.{ r.data, r.color }, .{ 85, .black });
    try expectEq(.{ l.data, l.color }, .{ 52, .black });
    try expectEq(.{ rr.data, rr.color }, .{ 93, .red });
}

test "find" {
    var allocator = std.testing.allocator;
    const expectEq = std.testing.expectEqual;
    var tree = Tree(usize, compare).init(allocator);
    defer tree.deinit();

    try tree.insert(61);
    try tree.insert(52);
    try tree.insert(85);
    try tree.insert(93);

    const matcher = struct {
        pub fn find(a: usize) bool {
            return a > 90;
        }
    }.find;

    var node = tree.find(matcher) orelse @panic("node not found");
    try expectEq(node.data, 93);

    const matcher2 = struct {
        pub fn find(a: usize) bool {
            return a > 50;
        }
    }.find;

    node = tree.find(matcher2) orelse @panic("node not found");
    try expectEq(node.data, 52);
}

test "delete" {
    var allocator = std.testing.allocator;
    const expectEq = std.testing.expectEqual;
    var tree = Tree(usize, compare).init(allocator);
    defer tree.deinit();

    //       B(61)                        B(85)
    // B(52)       B(85)     -->    B(61)       B(93)
    //                R(93)

    try tree.insert(61);
    try tree.insert(52);
    try tree.insert(85);
    try tree.insert(93);

    const matcher = struct {
        pub fn find(comptime a: usize) fn (b: usize) bool {
            return struct {
                fn match(val: usize) bool {
                    return val > a;
                }
            }.match;
        }
    }.find;

    const node = tree.find(matcher(51)) orelse @panic("could not find node");
    try expectEq(node.data, 52);

    tree.delete(node);
    var head = tree.head.?;
    const left = head.leftChild() orelse @panic("left node is null");
    const right = head.rightChild() orelse @panic("right node is null");

    try expectEq(.{ head.data, head.color, head.parent }, .{ 85, .black, null });
    try expectEq(.{ left.data, left.color, left.parent }, .{ 61, .black, head });
    try expectEq(.{ right.data, right.color, right.parent }, .{ 93, .black, head });
    try expectEq(.{ left.leftChild(), left.rightChild() }, .{ null, null });
    try expectEq(.{ right.rightChild(), right.rightChild() }, .{ null, null });

    tree.delete(left);

    head = tree.head.?;
    try expectEq(.{ head.data, head.color, head.parent }, .{ 85, .black, null });
    try expectEq(.{ right.data, right.color, right.parent }, .{ 93, .red, head });
    try expectEq(head.leftChild(), null);
    try expectEq(.{ right.rightChild(), right.rightChild() }, .{ null, null });

    tree.delete(tree.head.?);

    head = tree.head orelse @panic("head is null");
    try expectEq(.{ head.data, head.color, head.parent }, .{ 93, .black, null });
    try expectEq(.{ head.leftChild(), head.rightChild() }, .{ null, null });

    tree.delete(tree.head.?);
    try expectEq(tree.head, null);
}
