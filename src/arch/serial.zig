const std = @import("std");
const format = std.fmt.format;
const Writer = std.io.Writer;
const SerialWriter = Writer(void, error{}, writeFn);

const io = @import("./io.zig");
const vga = @import("root").vga;
/// COM1
const PORT = 0x3F8;
const MAX_BAUD_RATE = 115200;
/// Line Control Register Offset
const LCR = 3;
// Interrupt Enable Register
const INT_ENABLE = 1;
// LINE STATUS Register
const LSR = 5;
const IRQ_LINE = 4; // for com ports 1 and 3

pub fn init() void {
    // set DLAB (Divisor Latch Access Bit)
    io.out(PORT + LCR, @as(u8, 1 << 7));

    // 38,400 baud rate
    io.out(PORT, @as(u8, 3));
    io.out(PORT + INT_ENABLE, @as(u8, 0));
    // set char len, stop bits and disable parity bit
    io.out(PORT + LCR, @as(u8, 0b11));
}

fn transmit_empty() bool {
    const data = io.in(PORT + LSR, u8);
    return (data & 0x20) != 0;
}

fn writeFn(_: void, str: []const u8) !usize {
    while (!transmit_empty()) {}

    for (str) |char| {
        io.out(PORT, char);
    }

    return str.len;
}

fn writer() SerialWriter {
    return .{ .context = {} };
}

pub fn write(comptime str: []const u8, args: anytype) void {
    format(writer(), str, args) catch {};
}

pub fn writeln(comptime str: []const u8, args: anytype) void {
    format(writer(), str, args) catch {};
    io.out(PORT, @as(u8, '\n'));
}
