const std = @import("std");
const log = std.log.scoped(.vmm);
const BitMap = @import("BitMap.zig").BitMap;

const arch = @import("arch");
const pg = arch.paging;
const MemoryRegion = @import("memmap.zig").MemoryRegion;
const MemMapEntry = @import("../boot/mutliboot_header.zig").MemMapEntry;
const FrameAllocator = @import("pmm.zig");

const Self = @This();

pmm: *FrameAllocator,
page_directory: *pg.PageDirectory,

pub fn init(page_directory: *pg.PageDirectory, pmm: *FrameAllocator, reserved: []MemoryRegion) !Self {
    for (reserved) |res| {
        page_directory.mapRegions(res.start, res.start, res.size);
        try pmm.allocRegion(res.start, res.size);
    }

    return .{
        .pmm = pmm,
        .page_directory = page_directory,
    };
}

pub fn enablePaging(self: *Self) void {
    self.page_directory.load();
    pg.enable_paging();
}
