const arch = @import("arch");
const paging = arch.paging;

const mem = @import("../mem/mem.zig");
const PhysFrameAllocator = mem.pmm;

page_dir: paging.PageDirectory align(paging.PAGE_SIZE),

const Self = @This();

pub fn init() Self {
    return .{ .page_dir = paging.PageDirectory.init() };
}

pub fn deinit(self: *Self, cb: *const fn (usize) void) void {
    self.page_dir.deinit(cb);
}

pub fn mapPages(
    self: *Self,
    virt_addr: usize,
    size: usize,
    phys_frame_allocator: *PhysFrameAllocator,
) !void {
    var start: usize = 0;
    while (start < size) : (start += paging.PAGE_SIZE) {
        const phys_addr = try phys_frame_allocator.alloc();
        self.page_dir.mapUserPage(virt_addr + start, phys_addr);
    }
}
