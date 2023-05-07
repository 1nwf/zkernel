const memmap = @import("memmap.zig");
const util = @import("../../util.zig");

const std = @import("std");

const PAGE_SIZE = 4096;
pub const MemRegion = struct {
    start: u64,
    end: u64,
    fn init(start: u64, end: u64) MemRegion {
        return MemRegion{ .start = start, .end = end };
    }
};

pub const Frame = struct {
    size: usize,
    next: ?*allowzero Frame,
    fn init(size: usize, next: ?*Frame) Frame {
        return Frame{ .size = size, .next = next };
    }
};

pub const FrameAllocator = struct {
    start: *allowzero Frame,
    count: usize = 0,

    pub fn init(map: []memmap.SMAPEntry) FrameAllocator {
        var frame = FrameAllocator{ .start = undefined, .count = 0 };

        for (map) |region| {
            if (region.length < PAGE_SIZE) {
                continue;
            }

            var prev_frame: ?*allowzero Frame = null;

            var iter = util.stepBy(@intCast(usize, region.base), @intCast(usize, region.base + region.length), PAGE_SIZE);
            while (iter.next()) |val| {
                const end = val + PAGE_SIZE - 1;
                if (end > (region.base + region.length)) {
                    break;
                }
                var f = @intToPtr(*allowzero Frame, val);
                f.size = PAGE_SIZE;

                if (prev_frame) |prev| {
                    prev.next = f;
                } else {
                    frame.start = f;
                }
                prev_frame = f;

                frame.count += 1;
            }
        }
        return frame;
    }
};
