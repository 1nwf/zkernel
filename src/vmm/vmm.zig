const std = @import("std");
const log = std.log.scoped(.vmm);

const arch = @import("arch");
const pg = arch.paging;
pub const MemoryRegion = @import("memmap.zig").MemRegion;
const BumpAlloc = @import("bump_alloc.zig").BumpAllocator;
const MemMapEntry = @import("../boot/mutliboot_header.zig").MemMapEntry;

const Self = @This();

pmm: BumpAlloc,
pg_dir: pg.PageDirectory align(pg.PAGE_SIZE),

pub fn init(mem_map: []MemMapEntry, reserved: []MemoryRegion) Self {
    var pg_dir: pg.PageDirectory align(pg.PAGE_SIZE) = pg.PageDirectory.init();
    var allocator = BumpAlloc.init(mem_map, reserved, &pg_dir);
    for (reserved) |res| {
        pg_dir.mapRegions(res.start, res.start, res.end - res.start);
    }

    return .{
        .pmm = allocator,
        .pg_dir = pg_dir,
    };
}

pub fn enablePaging(self: *Self) void {
    self.pg_dir.load();
    pg.enable_paging();
}

test {
    _ = BumpAlloc;
}
