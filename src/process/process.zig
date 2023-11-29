const arch = @import("arch");
const paging = arch.paging;

page_dir: paging.PageDirectory align(paging.PAGE_SIZE),

const Self = @This();

pub fn init() Self {
    return .{ .page_dir = paging.PageDirectory.init() };
}

pub fn deinit(self: *Self) void {
    self.page_dir.deinit();
}
