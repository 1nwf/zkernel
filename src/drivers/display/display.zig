const pci = @import("../pci/pci.zig");
const std = @import("std");
const log = std.log.scoped(.vga);
const arch = @import("arch");
const paging = arch.paging;
const framebuffer = @import("framebuffer.zig");
pub const Pixel = framebuffer.Pixel;
pub const font = @import("font.zig");

pub usingnamespace @import("graphics.zig");
const vga = @import("vga.zig");

pub var width: usize = 0;
pub var height: usize = 0;
pub fn init(dev: *pci.Device, page_dir: *paging.PageDirectory) void {
    framebuffer.framebuffer = vga.init(dev, page_dir);
    width = framebuffer.framebuffer.width;
    height = framebuffer.framebuffer.height;
}
