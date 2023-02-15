const vga = @import("drivers/vga.zig");
const cursor = @import("drivers/cursor.zig");
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
    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);
    vga.writeln("hello world", .{});

    halt();
}
