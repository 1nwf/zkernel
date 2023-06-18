const std = @import("std");

pub const StepIterator = struct {
    start: u64,
    end: u64,
    step_size: u64,
    next_val: ?u64,
    pub fn init(start: u64, end: u64, step_size: u64) StepIterator {
        return StepIterator{ .start = start, .end = end, .step_size = step_size, .next_val = null };
    }
    pub fn next(self: *StepIterator) ?u64 {
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
pub fn stepBy(start: u64, stop: u64, step: u64) StepIterator {
    return StepIterator.init(start, stop, step);
}
