const vga = @import("drivers/vga.zig");
// kernel entry
// has custom .entry section that is placed first in the .text section
export fn entry() linksection(".entry") void {
    main();
}

fn main() void {
    var screen = vga.create(.{ .bg = vga.Color.LightRed, .fg = vga.Color.White });
    screen.write("w" ** 2000);
    screen.write("last row");
}
