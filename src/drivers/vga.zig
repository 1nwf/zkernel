const cursor = @import("cursor.zig");
const std = @import("std");
const Writer = std.io.Writer;
const format = std.fmt.format;

// vga text buffer
const buffer: [*]volatile Char = @ptrFromInt(0xb8000);
pub const VGAWriter = Writer(*Screen, error{}, writeFn);
const max_height = 25;
const max_width = 80;

pub const Screen = @This();
var screen: Screen = undefined;

pub const Color = enum(u4) {
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGrey,
    DarkGrey,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    LightBrown,
    White,
};

const Style = packed struct {
    fg: Color = Color.White,
    bg: Color = Color.Black,
    fn create(bg: Color, fg: Color) Style {
        return Style{ .bg = bg, .fg = fg };
    }
};

pub const Char = packed struct {
    //  bg    fg   ascii
    // 0b0000_1111_01101001;
    ascii: u8,
    style: Style,

    pub fn create(char: u8, style: Style) Char {
        return Char{ .style = style, .ascii = char };
    }
};

height: u16 = 0,
width: u16 = 0,
style: Style = .{},

pub fn init(style: Style, cursor_shape: cursor.Shape) void {
    screen = Screen{ .style = style };
    cursor.setShape(cursor_shape);
    cursor.setLocation(0);
    screen.clearScreen();
}

pub fn setColor(style: Style) void {
    style = style;
}

pub fn clearScreen(self: *Screen) void {
    const empty_char = Char.create(' ', self.style);
    var idx: usize = 0;
    while (idx < 2000) : (idx += 1) {
        buffer[idx] = empty_char;
    }
    self.height = 0;
    self.width = 0;
}
fn newLine(self: *Screen) void {
    self.height += 1;
    self.width = 0;
    if (self.height >= max_height) {
        self.scroll();
    }
}

pub fn scroll(self: *Screen) void {
    var idx: usize = 80;
    const empty_char = Char.create(' ', self.style);
    const currentIdx = (self.height * max_width) + self.width;
    while (idx != currentIdx) : (idx += 1) {
        buffer[idx - 80] = buffer[idx];
        buffer[idx] = empty_char;
    }

    self.height -= 1;
    const cursor_location: u16 = self.height * max_width + self.width;
    cursor.setLocation(cursor_location);
}

fn putCharAt(self: *Screen, c: u8, y: usize, x: usize) void {
    const char = Char.create(c, self.style);
    const index = (y * max_width) + x;
    buffer[index] = char;

    self.width += 1;
    if (self.width == max_width) {
        self.width = 0;
        self.height += 1;
    }
    if (self.height >= max_height) {
        self.scroll();
    }
}

pub fn putChar(self: *Screen, c: u8) void {
    switch (c) {
        '\n' => return self.newLine(),
        else => return self.putCharAt(c, self.height, self.width),
    }
}

fn writeStr(self: *Screen, bytes: []const u8) void {
    for (bytes) |c| {
        self.putChar(c);
    }
}
inline fn writer(self: *Screen) VGAWriter {
    return @as(VGAWriter, .{ .context = self });
}

pub fn write(comptime data: []const u8, args: anytype) void {
    format(screen.writer(), data, args) catch {};
}

pub fn writeln(comptime data: []const u8, args: anytype) void {
    write(data, args);
    screen.newLine();
}

fn writeFn(self: *Screen, bytes: []const u8) error{}!usize {
    self.writeStr(bytes);
    const location: u16 = self.height * max_width + self.width;
    cursor.setLocation(location);

    return bytes.len;
}
