// vga text buffer
const buffer = @intToPtr([*]volatile Char, 0xb8000);
const max_height = 25;
const max_width = 80;

const Screen = @This();

const Color = enum(u4) {
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

    fn asInt(self: Color) u4 {
        return @enumToInt(self);
    }
};

const Style = packed struct {
    fg: u4 = @as(u4, Color.White.asInt()),
    bg: u4 = @as(u4, Color.Black.asInt()),
    fn create(bg: Color, fg: Color) Style {
        return Style{ .bg = bg.asInt(), .fg = fg.asInt() };
    }
};

const Char = packed struct {
    //  bg    fg   ascii
    // 0b0000_1111_01101001;
    ascii: u8,
    style: Style,

    fn create(char: u8, style: Style) Char {
        return Char{ .style = style, .ascii = char };
    }
};

height: u8 = 0,
width: u8 = 0,
style: Style = .{},

pub fn create(style: Style) Screen {
    return Screen{ .style = style };
}
pub fn setColor(self: *Screen, style: Style) void {
    _ = self;
    Screen.style = style;
}
pub fn clearScreen(self: *Screen) void {
    _ = self;
}
pub fn newLine(self: *Screen) void {
    _ = self;
}

pub fn putChar(self: *Screen, c: u8) void {
    const char = Char.create(c, self.style);
    var index = self.height * max_width + self.width;
    buffer[index] = char;
    self.width += 1;
    if (self.width == max_width) {
        if (self.height == max_height) {
            self.clearScreen();
        } else {
            self.height += 1;
            self.width = 0;
        }
    }
}

pub fn write(self: *Screen, str: []const u8) void {
    for (str) |c| {
        self.putChar(c);
    }
}
