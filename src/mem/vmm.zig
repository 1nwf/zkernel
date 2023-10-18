const std = @import("std");
const log = std.log.scoped(.vmm);
const BitMap = @import("BitMap.zig").BitMap;

const arch = @import("arch");
const pg = arch.paging;
const MemoryRegion = @import("memmap.zig").MemoryRegion;
const MemMapEntry = @import("../boot/mutliboot_header.zig").MemMapEntry;
const FrameAllocator = @import("pmm.zig");
const AddressSpaceManager = @import("address_space_manager.zig");

const Self = @This();

pmm: *FrameAllocator,
page_directory: *pg.PageDirectory,
address_space_manager: AddressSpaceManager,

pub fn init(page_directory: *pg.PageDirectory, pmm: *FrameAllocator, reserved: []MemoryRegion, a: std.mem.Allocator) !Self {
    var adm = AddressSpaceManager.init(a);
    var region = MemoryRegion.init(pg.PAGE_SIZE, std.mem.alignBackward(usize, std.math.maxInt(usize), pg.PAGE_SIZE) - pg.PAGE_SIZE);
    try adm.insert(region);

    for (reserved) |res| {
        page_directory.mapRegions(res.start, res.start, res.size);
        try pmm.allocRegion(res.start, res.size);
    }

    page_directory.load();
    pg.enable_paging();

    return .{
        .pmm = pmm,
        .page_directory = page_directory,
        .address_space_manager = adm,
    };
}

pub fn allocate(self: *Self, len: usize) ![*]u8 {
    const region = try self.address_space_manager.allocate(len);
    const num_pages = region.size / pg.PAGE_SIZE;
    errdefer self.address_space_manager.free(region) catch {};
    if (!self.pmm.hasCapacity(num_pages)) return error.OutOfMemory;

    for (0..num_pages) |i| {
        const frame = try self.pmm.alloc();
        const virt_start = region.start + (i * pg.PAGE_SIZE);
        self.page_directory.mapPage(virt_start, frame);
    }

    const slice: [*]u8 = @ptrFromInt(region.start);
    return slice;
}

pub fn alloc(ctx: *anyopaque, len: usize, _: u8, _: usize) ?[*]u8 {
    var self: *Self = @ptrCast(@alignCast(ctx));
    return self.allocate(len) catch null;
}

fn resize(_: *anyopaque, _: []u8, _: u8, _: usize, _: usize) bool {
    return false;
}

fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, _: usize) void {
    _ = buf;
    _ = buf_align;
    var self: *Self = @ptrCast(@alignCast(ctx));
    _ = self;
}

pub fn allocator(self: *Self) std.mem.Allocator {
    return std.mem.Allocator{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .free = free,
        },
    };
}
