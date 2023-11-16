pub const serial = @import("arch/serial.zig");
pub const gdt = @import("arch/gdt.zig");
pub const paging = @import("arch/paging/paging.zig");
pub const virt_mem = @import("arch/paging/mem.zig");

pub const io = @import("arch/io.zig");

test {
    _ = paging;
}

pub fn halt() noreturn {
    asm volatile ("sti");
    while (true) {
        asm volatile ("hlt");
    }
}
