const std = @import("std");
const log = std.log.scoped(.graphics);
const framebuffer = @import("framebuffer.zig");
const Pixel = framebuffer.Pixel;

fn drawPixel(pixel: Pixel, x: usize, y: usize) void {
    const pos = ((y * framebuffer.framebuffer.width) + x);
    framebuffer.framebuffer.ptr[pos] = pixel;
}

fn drawLine(pixel: Pixel, x: usize, y: usize, width: usize) void {
    const pos = ((y * framebuffer.framebuffer.width) + x);
    var p = pixel;
    @memset(framebuffer.framebuffer.ptr[pos .. pos + width], p);
}

pub fn drawRect(pixel: Pixel, x: usize, y: usize, width: usize, height: usize) void {
    for (y..y + height) |h| {
        drawLine(pixel, x, h, width);
    }
}
