const std = @import("std");
const stdlib = @import("stdlib");

pub export fn _start() void {
    stdlib.write("hello");
    while (true) {}
}
