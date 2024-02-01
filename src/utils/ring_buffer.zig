const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime size: usize) type {
    return struct {
        const static = size != null;
        const Self = @This();
        head: usize = 0,
        len: usize = 0,

        buffer: [size]?T,

        pub fn init() Self {
            return Self{
                .buffer = [_]?T{null} ** size,
            };
        }

        pub fn isFull(self: *Self) bool {
            return self.len == self.buffer.len;
        }

        pub fn isEmpty(self: *Self) bool {
            return self.len == 0;
        }

        fn getIdx(self: *Self, idx: usize) usize {
            return (self.head + idx) % self.buffer.len;
        }

        /// append value to buffer and return its index
        pub fn append(self: *Self, value: T) !usize {
            if (self.isFull()) return error.Full;
            const idx = self.getIdx(self.len);
            self.buffer[idx] = value;
            self.len += 1;
            return idx;
        }

        pub fn pop(self: *Self) ?T {
            const value = self.buffer[self.head];
            self.buffer[self.head] = null;
            self.len -= 1;
            self.head = self.getIdx(1);
            return value;
        }
    };
}

test {
    const expectEq = std.testing.expectEqual;
    const size = 10;
    var rb = RingBuffer(usize, size).init();
    for (0..size) |val| {
        try expectEq(try rb.append(val), val);
    }

    try std.testing.expectError(error.Full, rb.append(1));

    try expectEq(rb.pop(), 0);
    try expectEq(try rb.append(20), 0);
}
