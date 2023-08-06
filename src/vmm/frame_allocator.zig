const boot = @import("../../boot/mutliboot_header.zig");
const std = @import("std");
const util = @import("../../util.zig");
const serial = @import("root").serial;
const root = @import("root");
const vga = root.vga;

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

    pub fn init(map: []boot.MemMapEntry) Self {
        var frame = Self{};
        const kernel_start = root.kernel_start;
        const kernel_end = root.kernel_end;

        for (map) |*region| {
            if (region.type != boot.MemType.Available or region.length < PAGE_SIZE) continue;

            var prev_frame: ?*allowzero Frame = null;

            var region_end = region.base_addr + region.length;
            var iter = util.stepBy(u64, region.base_addr, region_end, PAGE_SIZE);

            while (iter.next()) |val| {
                if (val >= kernel_start and val <= kernel_end) {
                    continue;
                }

                var f: *allowzero Frame = @ptrFromInt(@as(usize, @truncate(val)));
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

    pub fn alloc(self: *Self) !*allowzero anyopaque {
        if (self.start) |frame| {
            self.start = frame.next;
            self.count -= 1;

            return frame;
        }

        return error.OutOfMemory;
    }

    pub fn free(self: *Self, ptr: *anyopaque) void {
        std.debug.assert(~(@intFromPtr(ptr) & 0xfff));
        var frame: *allowzero Frame = @ptrCast(ptr);
        frame.size = PAGE_SIZE;
        frame.next = self.start;
        self.start = frame;
        self.count += 1;
    }
};
