const std = @import("std");
const stdlib = @import("stdlib");

pub export fn _start() void {
    stdlib.write("hello");
    stdlib.write("this is a program running in userspace!");
    while (true) {}
}
