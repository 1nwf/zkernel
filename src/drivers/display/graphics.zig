const std = @import("std");
const log = std.log.scoped(.graphics);
const fb = @import("framebuffer.zig");
const Pixel = fb.Pixel;

pub fn drawPixel(pixel: Pixel, x: usize, y: usize) void {
    const pos = ((y * fb.framebuffer.width) + x);
    fb.framebuffer.ptr[pos] = pixel;
}

fn drawLine(pixel: Pixel, x: usize, y: usize, width: usize) void {
    const pos = ((y * fb.framebuffer.width) + x);
    var p = pixel;
    @memset(fb.framebuffer.ptr[pos .. pos + width], p);
}

pub fn drawRect(pixel: Pixel, x: usize, y: usize, width: usize, height: usize) void {
    for (y..y + height) |h| {
        drawLine(pixel, x, h, width);
    }
}

pub fn setBackground(pixel: Pixel) void {
    const len: usize = @as(usize, fb.framebuffer.width) * fb.framebuffer.height;
    @memset(fb.framebuffer.ptr[0..len], pixel);
}
