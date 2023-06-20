const memmap = @import("memmap.zig");
const util = @import("../../util.zig");
const serial = @import("root").serial;
const vga = @import("root").vga;

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
    start: ?*allowzero Frame = null,
    count: usize = 0,

    const Self = @This();

    pub noinline fn init(map: []memmap.MemMapEntry) Self {
        var frame = Self{};

        for (map) |*region| {
            if (region.length < PAGE_SIZE) {
                continue;
            }

            var prev_frame: ?*allowzero Frame = null;

            var region_end = region.base + region.length;
            var iter = util.stepBy(u64, region.base, region_end, PAGE_SIZE);

            while (iter.next()) |val| {
                const end = val + PAGE_SIZE - 1;
                if (end > (region.base + region.length)) {
                    break;
                }

                var f = @intToPtr(*allowzero Frame, @truncate(usize, val));
                f.size = PAGE_SIZE;

                if (frame.start == null) {
                    frame.start = f;
                } else if (prev_frame) |prev| {
                    prev.next = f;
                }

                prev_frame = f;
                frame.count += 1;
            }
        }

        return frame;
    }

    pub inline fn alloc(self: *Self) !*allowzero anyopaque {
        if (self.start) |frame| {
            self.start = frame.next;
            self.count -= 1;

            return frame;
        }

        return error.OutOfMemory;
    }

    pub inline fn free(self: *Self, ptr: *anyopaque) void {
        var frame = @ptrCast(*allowzero Frame, ptr);
        frame.size = PAGE_SIZE;
        frame.next = self.start;
        self.start = frame;
        self.count += 1;
    }
};
