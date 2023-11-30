const std = @import("std");
const Writer = std.io.Writer(void, error{}, writeFn);

fn write(str: []const u8) void {
    asm volatile (
        \\ xor %%eax, %%eax
        \\ int $48
        :
        : [value] "{ebx}" (&str),
    );
}

fn writeFn(_: void, str: []const u8) !usize {
    write(str);
    return str.len;
}

fn writer() Writer {
    return .{ .context = {} };
}

pub fn print(comptime str: []const u8, args: anytype) void {
    std.fmt.format(writer(), str, args) catch {};
}

pub fn println(comptime str: []const u8, args: anytype) void {
    std.fmt.format(writer(), str ++ "\n", args) catch {};
}
