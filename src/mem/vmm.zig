const std = @import("std");
const log = std.log.scoped(.vmm);
const BitMap = @import("BitMap.zig").BitMap;

const arch = @import("arch");
const pg = arch.paging;
const MemoryRegion = @import("memmap.zig").MemoryRegion;
const FrameAllocator = @import("frame_allocator.zig").FrameAllocator;
const MemMapEntry = @import("../boot/mutliboot_header.zig").MemMapEntry;

const Self = @This();

pmm: FrameAllocator,
page_directory: *pg.PageDirectory,
free_ptr: ?[]u8 = null,

pub fn init(page_directory: *pg.PageDirectory, mem_map: []MemMapEntry, reserved: []MemoryRegion) Self {
    var allocator = FrameAllocator.init(mem_map, reserved, page_directory);
    // TODO: map kernel at higher virtual mem address
    for (reserved) |res| {
        page_directory.mapRegions(res.start, res.start, res.end - res.start);
    }

    return .{
        .pmm = allocator,
        .page_directory = page_directory,
    };
}

pub fn enablePaging(self: *Self) void {
    self.page_directory.load();
    pg.enable_paging();
}
