const std = @import("std");
const writeln = @import("arch").serial.writeln;

pub fn printStackTrace() void {
    var stack = std.debug.StackIterator.init(null, null);
    defer stack.deinit();
    writeln("stack trace start----", .{});
    while (stack.next()) |addr| {
        writeln("0x{x}", .{addr});
    }
    writeln("stack trace end------", .{});
}
