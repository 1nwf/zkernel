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

fn readVgaData(register: u8) u8 {
    io.out(address, register);
    return io.in(data, u8);
}

/// start and end between 0-15. start can't be greater than end or cursor will be hidden
fn enableCursor(start: u8, end: u8) void {
    sendVgaData(cursor_start, start);
    sendVgaData(cursor_end, end);
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

pub fn getLocation() u16 {
    const lower = readVgaData(cursor_location_low);
    const upper: u16 = readVgaData(cursor_location_high);
    return (upper << 8) | lower;
}

const Shape = enum {
    Block,
    Underline,

    fn start(self: Shape) u8 {
        return switch (self) {
            .Block => 0,
            .Underline => 14,
        };
    }
    fn end(self: Shape) u8 {
        _ = self;
        return 15;
    }
};

pub fn setShape(shape: Shape) void {
    enableCursor(shape.start(), shape.end());
}
