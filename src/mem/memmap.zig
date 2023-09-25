const std = @import("std");
const PAGE_SIZE = @import("arch").paging.PAGE_SIZE;
const arch = @import("arch");
pub const MemMapEntry = @import("../boot/mutliboot_header.zig").MemMapEntry;

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

pub const MemoryRegion = struct {
    start: usize,
    size: usize,

    pub fn init(start: usize, size: usize) @This() {
        return .{
            .start = std.mem.alignBackward(usize, start, PAGE_SIZE),
            .size = std.mem.alignForward(usize, size, PAGE_SIZE),
        };
    }

    pub fn end(self: *const @This()) usize {
        return self.start + self.size;
    }
};
