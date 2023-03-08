const vga = @import("drivers/vga.zig");
const int = @import("interrupts/idt.zig");
const timer = @import("interrupts/timer.zig");

// kernel entry
// has custom .entry section that is placed first in the .text section
export fn entry() linksection(".entry") void {
    main();
}

fn halt() noreturn {
    asm volatile ("sti");
    while (true) {
        asm volatile ("hlt");
    }
}

fn main() noreturn {
    vga.init(.{ .bg = .LightRed, .fg = .White }, .Underline);
    int.enable();
    int.init();
    int.load();

    var secs: u8 = 0;
    while (secs < 10) : (secs += 1) {
        timer.wait(1);
        vga.write("{} ", .{secs + 1});
    }

    halt();
}
