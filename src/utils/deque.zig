const std = @import("std");
pub fn Deque(comptime T: type, comptime initial_size: usize) type {
    return struct {
        const Self = @This();
        items: []T,
        allocator: std.mem.Allocator,
        head: usize = 0,
        len: usize = 0,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .items = try allocator.alloc(T, initial_size),
                .allocator = allocator,
            };
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        pub fn popFront(self: *Self) ?T {
            if (self.isEmpty()) return null;
            const item = self.items[self.head];
            self.head = self.next(self.head);
            self.len -= 1;
            return item;
        }

        pub fn pushBack(self: *Self, item: T) !void {
            try self.growIfFull();
            self.items[self.index()] = item;
            self.len += 1;
        }

        fn index(self: *Self) usize {
            return (self.len + self.head) % self.items.len;
        }

        fn next(self: *Self, n: usize) usize {
            return (n + 1) % self.items.len;
        }

        fn isFull(self: *Self) bool {
            return self.len == self.items.len;
        }

        fn growIfFull(self: *Self) !void {
            if (!self.isFull()) return;

            const current_idx = self.index();
            if (self.allocator.resize(self.items, self.items.len * 2) == true) {
                if (current_idx > self.head) return;
                @memcpy(self.items[self.len..], self.items[0..current_idx]);
                return;
            }

            var new_buff = try self.allocator.alloc(T, self.items.len * 2);

            if (current_idx > self.head) {
                @memcpy(new_buff[0..self.items.len], self.items);
            } else {
                const len = self.len - self.head;
                @memcpy(new_buff[0..len], self.items[self.head..]);
                @memcpy(new_buff[len .. len + self.head], self.items[0..self.head]);
                self.head = 0;
            }
            self.allocator.free(self.items);
            self.items = new_buff;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }
    };
}
