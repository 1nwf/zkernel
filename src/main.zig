const vga = @import("drivers/vga.zig");
const vga_buffer = @intToPtr([*]volatile u8, 0xB8000);

// kernel entry
// has custom .entry section that is placed first in the .text section
export fn entry() linksection(".entry") void {
    main();
}

export fn main() void {
    var screen = vga.create(.{});
    screen.write("w\nw");
}
