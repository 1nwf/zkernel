const pci = @import("../pci/pci.zig");
const std = @import("std");
const log = std.log.scoped(.vga);
const arch = @import("arch");
const io = arch.io;
const paging = arch.paging;
const FrameBuffer = @import("framebuffer.zig").FrameBuffer;

const INDEX = 0x01CE;
const DATA = 0x01CF;
const Index = enum(u16) {
    ID = 0,
    XRES = 1,
    YRES = 2,
    BPP = 3,
    ENABLE = 4,
    BANK = 5,
    VIRT_WIDTH = 6,
    VIRT_HEIGHT = 7,
    X_OFFSET = 8,
    Y_OFFSET = 9,
};

fn writeConfig(index: Index, data: u16) void {
    io.out(INDEX, @intFromEnum(index));
    io.out(DATA, data);
}

fn readConfig(index: Index, comptime size: type) size {
    io.out(INDEX, @intFromEnum(index));
    return io.in(DATA, size);
}

pub fn init(dev: *pci.Device, page_dir: *paging.PageDirectory) FrameBuffer {
    const fb_addr = dev.read_bar(0).Mem;
    const framebuffer = FrameBuffer{
        .width = 1000,
        .height = 600,
        .ptr = @ptrFromInt(fb_addr),
    };
    const pixel_count = @as(u32, framebuffer.width) * framebuffer.height;
    const id = readConfig(.ID, u16);
    log.info("id: 0x{x}", .{id});

    writeConfig(.ENABLE, 0);
    writeConfig(.XRES, framebuffer.width);
    writeConfig(.YRES, framebuffer.height);
    writeConfig(.BPP, 0x20);
    writeConfig(.ENABLE, 0x40 | 0x1);

    log.info("framebuffer addr: 0x{x}", .{fb_addr});
    page_dir.mapRegions(fb_addr, fb_addr, 4 * pixel_count);
    return framebuffer;
}
