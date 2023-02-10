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

pub const Char = packed struct {
    //  bg    fg   ascii
    // 0b0000_1111_01101001;
    ascii: u8,
    style: Style,

    pub fn create(char: u8, style: Style) Char {
        return Char{ .style = style, .ascii = char };
    }
};

height: usize = 0,
width: usize = 0,
style: Style = .{},

pub fn create(style: Style) Screen {
    var s = Screen{ .style = style };
    s.clearScreen();
    return s;
}
pub fn setColor(self: *Screen, style: Style) void {
    self.style = style;
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
pub fn newLine(self: *Screen) void {
    self.height += 1;
    self.width = 0;
}

fn scroll(self: *Screen) void {
    _ = self;
}

pub fn putChar(self: *Screen, c: u8) void {
    const char = Char.create(c, self.style);
    var index = (self.height * max_width) + self.width;
    buffer[index] = char;

    switch (char.ascii) {
        '\n' => return self.newLine(),
        else => buffer[index] = char,
    }

    self.width += 1;
    if (self.width == max_width) {
        self.width = 0;
        self.height += 1;
        if (self.height == max_height) {
            //TODO: scroll if needed
            self.clearScreen();
        }
    }
}

pub fn write(self: *Screen, str: []const u8) void {
    for (str) |c| {
        self.putChar(c);
    }
}
