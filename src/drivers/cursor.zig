const io = @import("../io.zig");

/// address register
const address: u16 = 0x3D4;
/// data register
const data: u16 = 0x3d5;

/// registers for controlling appearance of cursor
const cursor_start: u16 = 0x0A;
const cursor_end: u16 = 0x0B;

/// registers for setting low and high bits of cursor location
const cursor_location_high: u8 = 0x0E;
const cursor_location_low: u8 = 0x0F;

/// start and end between 0-15. start can't be greater than end or cursor will be hidden
pub fn enableCursor(start: u8, end: u8) void {
    io.out(address, cursor_start);
    io.out(data, start);

    io.out(address, cursor_end);
    io.out(data, end);

    setLocation(0);
}

pub fn disableCursor() void {
    io.out(address, cursor_start);
    io.out(data, @as(u8, 0x20));
}

pub fn setLocation(pos: u16) void {
    const upper: u8 = @truncate(u8, (pos & 0xFF00) >> 8);
    const lower: u8 = @truncate(u8, pos & 0x00FF);

    io.out(address, cursor_location_high);
    io.out(data, upper);

    io.out(address, cursor_location_low);
    io.out(data, lower);
}
