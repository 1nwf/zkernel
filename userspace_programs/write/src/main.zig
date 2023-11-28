const std = @import("std");
const stdlib = @import("stdlib");

pub export fn _start() void {
    stdlib.println("hello", .{});
    stdlib.println("this is a program running in userspace!", .{});
    while (true) {}
}
