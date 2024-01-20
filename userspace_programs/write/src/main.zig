const std = @import("std");
const stdlib = @import("stdlib");

export fn main() void {
    stdlib.println("hello", .{});
    stdlib.println("this is a program running in userspace!", .{});

    for (0..5) |i| {
        stdlib.println("p1: {}", .{i});
        stdlib.yeild();
    }
}
