const memap = @import("memmap.zig");
const util = @import("../../util.zig");

pub const MemRegion = struct {
    start: u64,
    end: u64,
    fn init(start: u64, end: u64) MemRegion {
        return MemRegion{ .start = start, .end = end };
    }
};

pub const FrameAllocator = struct {
    frames: []MemRegion,
    pub fn init(memoryMap: []memap.SMAPEntry, frameAddr: usize) FrameAllocator {
        var frames = @intToPtr([]MemRegion, frameAddr);

        var count: usize = 0;
        for (memoryMap) |region| {
            var step_iter = util.stepBy(region.base, region.length, 4096 * 1024);

            while (step_iter.next()) |val| {
                const v = val / 1024;
                frames[count] = MemRegion.init(v, v + 4096);
                count += 1;
            }
        }

        frames.len = count;
        return FrameAllocator{ .frames = frames };
    }
};
