const vga = @import("drivers/vga.zig");
// kernel entry
// has custom .entry section that is placed first in the .text section
export fn entry() linksection(".entry") void {
    main();
}

fn main() noreturn {
    var screen = vga.create(.{ .bg = vga.Color.LightRed, .fg = vga.Color.White });
    screen.write("hello {s}", .{"kernel"});
    while (true) {
        asm volatile ("hlt");
    }
}
