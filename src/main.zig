const vga = @import("drivers/vga.zig");
const cursor = @import("drivers/cursor.zig");
const int = @import("interrupt.zig");
const std = @import("std");
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
    int.enable();
    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);
    vga.writeln("hello world", .{});
    int.init();
    int.load();

    asm volatile ("int $10");
    halt();
}
