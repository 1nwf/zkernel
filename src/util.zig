const std = @import("std");

fn StepIterator(comptime T: anytype) type {
    return struct {
        start: T,
        end: T,
        step_size: T,
        next_val: ?T,
        pub fn init(start: T, end: T, step_size: T) @This() {
            return .{ .start = start, .end = end, .step_size = step_size, .next_val = null };
        }
        pub fn next(self: *@This()) ?T {
            if (self.next_val) |val| {
                const nextVal = val + self.step_size;
                if (nextVal > self.end) {
                    self.next_val = null;
                    return null;
                }

                self.next_val = nextVal;
                return val;
            } else {
                self.next_val = self.start + self.step_size;
                return self.start;
            }
        }
    };
}
pub fn stepBy(comptime T: anytype, start: T, stop: T, step: T) StepIterator(T) {
    return StepIterator(T).init(start, stop, step);
}
