const std = @import("std");

pub const StepIterator = struct {
    start: usize,
    end: usize,
    step_size: usize,
    next_val: ?usize,
    pub fn init(start: usize, end: usize, step_size: usize) StepIterator {
        return StepIterator{ .start = start, .end = end, .step_size = step_size, .next_val = null };
    }

    pub fn next(self: *StepIterator) ?usize {
        if (self.next_val == null) {
            self.next_val = self.start;
            return self.next_val;
        }
        const nextVal = self.next_val.? + self.step_size;
        if (nextVal > self.end) {
            self.next_val = null;
            return null;
        }

        self.next_val = nextVal;
        return self.next_val;
    }
};
pub fn stepBy(start: usize, stop: usize, step: usize) StepIterator {
    return StepIterator.init(start, stop, step);
}
