const int = @import("../interrupts/interrupts.zig");
const in = @import("../io.zig").in;
const write = @import("vga.zig").write;

const unicode = @import("std").unicode;
const sendEoi = @import("../interrupts/pic.zig").sendEoi;
pub fn init_keyboard() void {
    int.setIrqHandler(1, keyboardHandler);
}

var modifiers = Modifiers.init();
export fn keyboardHandler(ctx: int.Context) void {
    _ = ctx;
    const scancode = in(0x60, u8);
    const key = Key.init(scancode);
    if (Modifiers.is_modifier(key)) {
        modifiers.update(key);
        return;
    }
    if (key.release) {
        return;
    }

    var letter = key.decode();

    write("{u}", .{letter.value});
}

// ported from https://crates.io/crates/pc-keyboard Us104Key keyboard layout
fn getKey(scancode: u8) KeyCode {
    return switch (scancode) {
        0x01 => KeyCode.Escape, // 01
        0x02 => KeyCode.Key1, // 02
        0x03 => KeyCode.Key2, // 03
        0x04 => KeyCode.Key3, // 04
        0x05 => KeyCode.Key4, // 05
        0x06 => KeyCode.Key5, // 06
        0x07 => KeyCode.Key6, // 07
        0x08 => KeyCode.Key7, // 08
        0x09 => KeyCode.Key8, // 09
        0x0A => KeyCode.Key9, // 0A
        0x0B => KeyCode.Key0, // 0B
        0x0C => KeyCode.Minus, // 0C
        0x0D => KeyCode.Equals, // 0D
        0x0E => KeyCode.Backspace, // 0E
        0x0F => KeyCode.Tab, // 0F
        0x10 => KeyCode.Q, // 10
        0x11 => KeyCode.W, // 11
        0x12 => KeyCode.E, // 12
        0x13 => KeyCode.R, // 13
        0x14 => KeyCode.T, // 14
        0x15 => KeyCode.Y, // 15
        0x16 => KeyCode.U, // 16
        0x17 => KeyCode.I, // 17
        0x18 => KeyCode.O, // 18
        0x19 => KeyCode.P, // 19
        0x1A => KeyCode.BracketSquareLeft, // 1A
        0x1B => KeyCode.BracketSquareRight, // 1B
        0x1C => KeyCode.Enter, // 1C
        0x1D => KeyCode.ControlLeft, // 1D
        0x1E => KeyCode.A, // 1E
        0x1F => KeyCode.S, // 1F
        0x20 => KeyCode.D, // 20
        0x21 => KeyCode.F, // 21
        0x22 => KeyCode.G, // 22
        0x23 => KeyCode.H, // 23
        0x24 => KeyCode.J, // 24
        0x25 => KeyCode.K, // 25
        0x26 => KeyCode.L, // 26
        0x27 => KeyCode.SemiColon, // 27
        0x28 => KeyCode.Quote, // 28
        0x29 => KeyCode.BackTick, // 29
        0x2A => KeyCode.ShiftLeft, // 2A
        0x2B => KeyCode.BackSlash, // 2B
        0x2C => KeyCode.Z, // 2C
        0x2D => KeyCode.X, // 2D
        0x2E => KeyCode.C, // 2E
        0x2F => KeyCode.V, // 2F
        0x30 => KeyCode.B, // 30
        0x31 => KeyCode.N, // 31
        0x32 => KeyCode.M, // 32
        0x33 => KeyCode.Comma, // 33
        0x34 => KeyCode.Fullstop, // 34
        0x35 => KeyCode.Slash, // 35
        0x36 => KeyCode.ShiftRight, // 36
        0x37 => KeyCode.NumpadStar, // 37
        0x38 => KeyCode.AltLeft, // 38
        0x39 => KeyCode.Spacebar, // 39
        0x3A => KeyCode.CapsLock, // 3A
        0x3B => KeyCode.F1, // 3B
        0x3C => KeyCode.F2, // 3C
        0x3D => KeyCode.F3, // 3D
        0x3E => KeyCode.F4, // 3E
        0x3F => KeyCode.F5, // 3F
        0x40 => KeyCode.F6, // 40
        0x41 => KeyCode.F7, // 41
        0x42 => KeyCode.F8, // 42
        0x43 => KeyCode.F9, // 43
        0x44 => KeyCode.F10, // 44
        0x45 => KeyCode.NumpadLock, // 45
        0x46 => KeyCode.ScrollLock, // 46
        0x47 => KeyCode.Numpad7, // 47
        0x48 => KeyCode.Numpad8, // 48
        0x49 => KeyCode.Numpad9, // 49
        0x4A => KeyCode.NumpadMinus, // 4A
        0x4B => KeyCode.Numpad4, // 4B
        0x4C => KeyCode.Numpad5, // 4C
        0x4D => KeyCode.Numpad6, // 4D
        0x4E => KeyCode.NumpadPlus, // 4E
        0x4F => KeyCode.Numpad1, // 4F
        0x50 => KeyCode.Numpad2, // 50
        0x51 => KeyCode.Numpad3, // 51
        0x52 => KeyCode.Numpad0, // 52
        0x53 => KeyCode.NumpadPeriod, // 53
        //0x54
        //0x55
        //0x56
        0x57 => KeyCode.F11, // 57
        0x58 => KeyCode.F12, // 58
        else => KeyCode.A,
    };
}

const Key = struct {
    code: KeyCode,
    release: bool,
    fn init(scancode: u8) Key {
        const code = getKey(scancode & 0x3F);
        const release = scancode >> 6 == 2;
        return Key{ .code = code, .release = release };
    }

    fn decode(self: Key) DecodedKey {
        return DecodedKey.fromKeyCode(self.code);
    }
};

const KeyCode = enum {
    AltLeft,
    AltRight,
    ArrowDown,
    ArrowLeft,
    ArrowRight,
    ArrowUp,
    BackSlash,
    Backspace,
    BackTick,
    BracketSquareLeft,
    BracketSquareRight,
    CapsLock,
    Comma,
    ControlLeft,
    ControlRight,
    Delete,
    End,
    Enter,
    Escape,
    Equals,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    Fullstop,
    Home,
    Insert,
    Key1,
    Key2,
    Key3,
    Key4,
    Key5,
    Key6,
    Key7,
    Key8,
    Key9,
    Key0,
    Menus,
    Minus,
    Numpad0,
    Numpad1,
    Numpad2,
    Numpad3,
    Numpad4,
    Numpad5,
    Numpad6,
    Numpad7,
    Numpad8,
    Numpad9,
    NumpadEnter,
    NumpadLock,
    NumpadSlash,
    NumpadStar,
    NumpadMinus,
    NumpadPeriod,
    NumpadPlus,
    PageDown,
    PageUp,
    PauseBreak,
    PrintScreen,
    ScrollLock,
    SemiColon,
    ShiftLeft,
    ShiftRight,
    Slash,
    Spacebar,
    Tab,
    Quote,
    WindowsLeft,
    WindowsRight,
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
    /// Not on US keyboards
    HashTilde,
    // Scan code set 1 unique codes
    PrevTrack,
    NextTrack,
    Mute,
    Calculator,
    Play,
    Stop,
    VolumeDown,
    VolumeUp,
    WWWHome,
    // Sent when the keyboard boots
    PowerOnTestOk,
};

const Modifiers = struct {
    lshift: bool,
    rshift: bool,
    lctrl: bool,
    rctrl: bool,
    numlock: bool,
    capslock: bool,
    alt_gr: bool,

    fn init() Modifiers {
        return Modifiers{
            .lshift = false,
            .rshift = false,
            .lctrl = false,
            .rctrl = false,
            .numlock = false,
            .capslock = false,
            .alt_gr = false,
        };
    }

    fn is_shifted(self: Modifiers) bool {
        return self.rshift or self.lshift;
    }

    fn update(self: *Modifiers, key: Key) void {
        if (!key.release) {
            if (key.code == KeyCode.ShiftRight) {
                self.rshift = true;
            } else if (key.code == KeyCode.ShiftLeft) {
                self.lshift = true;
            } else if (key.code == KeyCode.ControlLeft) {
                self.lctrl = true;
            } else if (key.code == KeyCode.ControlRight) {
                self.rctrl = true;
            } else if (key.code == KeyCode.AltRight) {
                self.alt_gr = true;
            }
        } else {
            if (key.code == KeyCode.ShiftRight) {
                self.rshift = false;
            } else if (key.code == KeyCode.ShiftLeft) {
                self.lshift = false;
            } else if (key.code == KeyCode.ControlLeft) {
                self.lctrl = false;
            } else if (key.code == KeyCode.ControlRight) {
                self.rctrl = false;
            } else if (key.code == KeyCode.AltRight) {
                self.alt_gr = false;
            }
        }
    }

    fn is_caps(self: Modifiers) bool {
        return self.capslock or self.is_shifted();
    }

    fn is_modifier(key: Key) bool {
        const keys = [_]KeyCode{ KeyCode.ShiftRight, KeyCode.ShiftLeft, KeyCode.ControlLeft, KeyCode.ControlRight, KeyCode.CapsLock, KeyCode.NumpadLock, KeyCode.AltLeft, KeyCode.AltRight };
        inline for (keys) |k| {
            if (k == key.code) {
                return true;
            }
        }

        return false;
    }
};

const DecodedKey = struct {
    value: u21,
    fn init(comptime val: u21) DecodedKey {
        return DecodedKey{ .value = val };
    }

    fn fromKeyCode(keycode: KeyCode) DecodedKey {
        return switch (keycode) {
            KeyCode.BackTick => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('~');
                } else {
                    return DecodedKey.init('`');
                }
            },
            KeyCode.Escape => DecodedKey.init(0x1B),
            KeyCode.Key1 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('!');
                } else {
                    return DecodedKey.init('1');
                }
            },
            KeyCode.Key2 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('@');
                } else {
                    return DecodedKey.init('2');
                }
            },
            KeyCode.Key3 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('#');
                } else {
                    return DecodedKey.init('3');
                }
            },
            KeyCode.Key4 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('$');
                } else {
                    return DecodedKey.init('4');
                }
            },
            KeyCode.Key5 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('%');
                } else {
                    return DecodedKey.init('5');
                }
            },
            KeyCode.Key6 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('^');
                } else {
                    return DecodedKey.init('6');
                }
            },
            KeyCode.Key7 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('&');
                } else {
                    return DecodedKey.init('7');
                }
            },
            KeyCode.Key8 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('*');
                } else {
                    return DecodedKey.init('8');
                }
            },
            KeyCode.Key9 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('(');
                } else {
                    return DecodedKey.init('9');
                }
            },
            KeyCode.Key0 => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init(')');
                } else {
                    return DecodedKey.init('0');
                }
            },
            KeyCode.Minus => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('_');
                } else {
                    return DecodedKey.init('-');
                }
            },
            KeyCode.Equals => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('+');
                } else {
                    return DecodedKey.init('=');
                }
            },
            KeyCode.Backspace => DecodedKey.init(0x08),
            KeyCode.Tab => DecodedKey.init(0x09),
            KeyCode.Q => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0011}');
                if (modifiers.is_caps()) {
                    return DecodedKey.init('Q');
                } else {
                    return DecodedKey.init('q');
                }
            },
            KeyCode.W => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0017}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('W');
                } else {
                    return DecodedKey.init('w');
                }
            },
            KeyCode.E => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0005}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('E');
                } else {
                    return DecodedKey.init('e');
                }
            },
            KeyCode.R => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0012}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('R');
                } else {
                    return DecodedKey.init('r');
                }
            },
            KeyCode.T => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0014}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('T');
                } else {
                    return DecodedKey.init('t');
                }
            },
            KeyCode.Y => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0019}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('Y');
                } else {
                    return DecodedKey.init('y');
                }
            },
            KeyCode.U => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0015}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('U');
                } else {
                    return DecodedKey.init('u');
                }
            },
            KeyCode.I => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0009}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('I');
                } else {
                    return DecodedKey.init('i');
                }
            },
            KeyCode.O => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{000F}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('O');
                } else {
                    return DecodedKey.init('o');
                }
            },
            KeyCode.P => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0010}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('P');
                } else {
                    return DecodedKey.init('p');
                }
            },
            KeyCode.BracketSquareLeft => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('{');
                } else {
                    return DecodedKey.init('[');
                }
            },
            KeyCode.BracketSquareRight => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('}');
                } else {
                    return DecodedKey.init(']');
                }
            },
            KeyCode.BackSlash => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('|');
                } else {
                    return DecodedKey.init('\\');
                }
            },
            KeyCode.A => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0001}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('A');
                } else {
                    return DecodedKey.init('a');
                }
            },
            KeyCode.S => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0013}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('S');
                } else {
                    return DecodedKey.init('s');
                }
            },
            KeyCode.D => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0004}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('D');
                } else {
                    return DecodedKey.init('d');
                }
            },
            KeyCode.F => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0006}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('F');
                } else {
                    return DecodedKey.init('f');
                }
            },
            KeyCode.G => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0007}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('G');
                } else {
                    return DecodedKey.init('g');
                }
            },
            KeyCode.H => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0008}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('H');
                } else {
                    return DecodedKey.init('h');
                }
            },
            KeyCode.J => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{000A}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('J');
                } else {
                    return DecodedKey.init('j');
                }
            },
            KeyCode.K => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{000B}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('K');
                } else {
                    return DecodedKey.init('k');
                }
            },
            KeyCode.L => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{000C}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('L');
                } else {
                    return DecodedKey.init('l');
                }
            },
            KeyCode.SemiColon => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init(':');
                } else {
                    return DecodedKey.init(';');
                }
            },
            KeyCode.Quote => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('"');
                } else {
                    return DecodedKey.init('\'');
                }
            },
            // Enter gives LF, not CRLF or CR
            KeyCode.Enter => DecodedKey.init(10),
            KeyCode.Z => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{001A}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('Z');
                } else {
                    return DecodedKey.init('z');
                }
            },
            KeyCode.X => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0018}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('X');
                } else {
                    return DecodedKey.init('x');
                }
            },
            KeyCode.C => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0003}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('C');
                } else {
                    return DecodedKey.init('c');
                }
            },
            KeyCode.V => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0016}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('V');
                } else {
                    return DecodedKey.init('v');
                }
            },
            KeyCode.B => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{0002}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('B');
                } else {
                    return DecodedKey.init('b');
                }
            },
            KeyCode.N => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{000E}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('N');
                } else {
                    return DecodedKey.init('n');
                }
            },
            KeyCode.M => {
                // if map_to_unicode && modifiers.is_ctrl() {
                // return DecodedKey.init('\u{000D}');
                // }
                if (modifiers.is_caps()) {
                    return DecodedKey.init('M');
                } else {
                    return DecodedKey.init('m');
                }
            },
            KeyCode.Comma => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('<');
                } else {
                    return DecodedKey.init(',');
                }
            },
            KeyCode.Fullstop => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('>');
                } else {
                    return DecodedKey.init('.');
                }
            },
            KeyCode.Slash => {
                if (modifiers.is_shifted()) {
                    return DecodedKey.init('?');
                } else {
                    return DecodedKey.init('/');
                }
            },
            KeyCode.Spacebar => DecodedKey.init(' '),
            KeyCode.Delete => DecodedKey.init(127),
            KeyCode.NumpadSlash => DecodedKey.init('/'),
            KeyCode.NumpadStar => DecodedKey.init('*'),
            KeyCode.NumpadMinus => DecodedKey.init('-'),
            KeyCode.Numpad7 => {
                // if modifiers.numlock {
                return DecodedKey.init('7');
                // } else {
                // return DecodedKey.init(KeyCode.Home);
                // }
            },
            KeyCode.Numpad8 => {
                // if modifiers.numlock {
                return DecodedKey.init('8');
                // } else {
                // DecodedKey.init(KeyCode.ArrowUp);
                // }
            },
            KeyCode.Numpad9 => {
                // if modifiers.numlock {
                return DecodedKey.init('9');
                // } else {
                // DecodedKey.init(KeyCode.PageUp);
                // }
            },
            KeyCode.NumpadPlus => DecodedKey.init('+'),
            KeyCode.Numpad4 => {
                // if modifiers.numlock {
                return DecodedKey.init('4');
                // } else {
                // DecodedKey.init(KeyCode.ArrowLeft);
                // }
            },
            KeyCode.Numpad5 => DecodedKey.init('5'),
            KeyCode.Numpad6 => {
                // if modifiers.numlock {
                return DecodedKey.init('6');
                // } else {
                // return DecodedKey.init(KeyCode.ArrowRight);
                // }
            },
            KeyCode.Numpad1 => {
                // if modifiers.numlock {
                return DecodedKey.init('1');
                // } else {
                // return DecodedKey.init(KeyCode.End);
                // }
            },
            KeyCode.Numpad2 => {
                // if modifiers.numlock {
                return DecodedKey.init('2');
                // } else {
                // return DecodedKey.init(KeyCode.ArrowDown);
                // }
            },
            KeyCode.Numpad3 => {
                // if modifiers.numlock {
                return DecodedKey.init('3');
                // } else {
                // return DecodedKey.init(KeyCode.PageDown);
                // }
            },
            KeyCode.Numpad0 => {
                // if modifiers.numlock {
                return DecodedKey.init('0');
                // } else {
                // DecodedKey.init(KeyCode.Insert);
                // }
            },
            KeyCode.NumpadPeriod => {
                // if modifiers.numlock {
                return DecodedKey.init('.');
                // } else {
                // DecodedKey.init(127.into());
                // }
            },
            KeyCode.NumpadEnter => DecodedKey.init(10),
            else => DecodedKey.init(' '),
        };
    }
};
