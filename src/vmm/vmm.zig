const std = @import("std");
const log = std.log.scoped(.vmm);

const arch = @import("arch");
const pg = arch.paging;
pub const MemoryRegion = @import("memmap.zig").MemRegion;
const BumpAlloc = @import("bump_alloc.zig").BumpAllocator;
const MemMapEntry = @import("../boot/mutliboot_header.zig").MemMapEntry;

const Self = @This();

pmm: BumpAlloc,
page_directory: *pg.PageDirectory,

pub fn init(page_directory: *pg.PageDirectory, mem_map: []MemMapEntry, reserved: []MemoryRegion) Self {
    var allocator = BumpAlloc.init(mem_map, reserved, page_directory);
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

test {
    _ = BumpAlloc;
}
