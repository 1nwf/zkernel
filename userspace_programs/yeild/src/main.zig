const std = @import("stdlib");
export fn main() void {
    for (0..5) |i| {
        std.println("p2: {}", .{i});
        std.yeild();
    }

    while (true) {
        const msg = std.read(1);
        std.print("{u}", .{@as(u21, @intCast(msg.msg))});
    }
}
