const vga_buffer = @intToPtr([*]volatile u8, 0xB8000);

export fn entry() linksection(".entry") void {
    main();
}

export fn main() void {
    print_str("hello from zig");
}

fn print_str(values: []const u8) void {
    var i: u8 = 0;
    for (values) |v| {
        vga_buffer[i] = v;
        i += 2;
    }
}
