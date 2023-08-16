const std = @import("std");
const PAGE_SIZE = @import("arch").paging.PAGE_SIZE;

const Entry = struct {
    start: u32,
    size: u32,
    regionType: RegionType,
    fn init(start: u32, size: u32, regionType: RegionType) Entry {
        return Entry{ .start = start, .size = size, .regionType = regionType };
    }
};

const RegionType = enum {
    Kernel,
    Used,
    Available,
};

pub const MemRegion = struct {
    start: usize,
    end: usize,

    /// start and end MUST be page aligned
    pub fn init(start: usize, end: usize) @This() {
        std.debug.assert(start % PAGE_SIZE == 0);
        std.debug.assert(end % PAGE_SIZE == 0);

        return .{
            .start = start,
            .end = end,
        };
    }
};
