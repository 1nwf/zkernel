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

/// writes register value to CRTC address register and value to CRTC data register
fn sendVgaData(register: u8, value: anytype) void {
    io.out(address, register);
    io.out(data, value);
}

/// start and end between 0-15. start can't be greater than end or cursor will be hidden
pub fn enableCursor(start: u8, end: u8) void {
    sendVgaData(cursor_start, start);
    sendVgaData(cursor_end, end);

    setLocation(0);
}

pub fn disableCursor() void {
    sendVgaData(cursor_start, @as(u8, 0x20));
}

pub fn setLocation(pos: u16) void {
    const upper: u8 = @truncate(u8, (pos & 0xFF00) >> 8);
    const lower: u8 = @truncate(u8, pos & 0x00FF);

    sendVgaData(cursor_location_high, upper);
    sendVgaData(cursor_location_low, lower);
}
