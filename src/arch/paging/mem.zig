pub const pg = @import("paging.zig");
const std = @import("std");
const log = std.log.scoped(.virt_mem);
pub fn virtToPhys(ptr: *const anyopaque) ?u32 {
    const virt_addr = @intFromPtr(ptr);
    const page_table = pg.active_page_dir.getDirPageTable(virt_addr) orelse return null;
    const pt_entry = page_table.findEntry(virt_addr);
    return (@as(u32, pt_entry.address) << 12) | (virt_addr & 0xFFF);
}
