const vga = @import("drivers/vga.zig");
// kernel entry
// has custom .entry section that is placed first in the .text section
export fn entry() linksection(".entry") void {
    main();
}

fn halt() noreturn {
    asm volatile ("cli");
    while (true) {
        asm volatile ("hlt");
    }
}

fn main() noreturn {
    var screen = vga.create(.{ .bg = vga.Color.LightRed, .fg = vga.Color.White });

    comptime var i = 0;
    inline while (i < 24) : (i += 1) {
        screen.writeln("width: {} = height: {}", .{ screen.width, screen.height });
    }

    halt();
}
