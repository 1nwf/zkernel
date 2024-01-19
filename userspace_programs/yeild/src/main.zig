const std = @import("stdlib");
export fn main() void {
    for (0..5) |i| {
        std.println("p2: {}", .{i});
        std.yeild();
    }
}
