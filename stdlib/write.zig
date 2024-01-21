const std = @import("std");
const Writer = std.io.Writer(void, error{}, writeFn);
const writer: Writer = .{ .context = {} };
const Syscall = @import("syscalls").Syscall;

fn write(str: *const []const u8) void {
    asm volatile (
        \\ int $48
        :
        : [value] "{ebx}" (str),
          [_] "{eax}" (Syscall.Print),
    );
}

fn writeFn(_: void, str: []const u8) !usize {
    write(&str);
    return str.len;
}

pub fn print(comptime str: []const u8, args: anytype) void {
    std.fmt.format(writer, str, args) catch {};
}

pub fn println(comptime str: []const u8, args: anytype) void {
    std.fmt.format(writer, str ++ "\n", args) catch {};
}
