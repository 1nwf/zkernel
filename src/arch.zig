pub const serial = @import("arch/serial.zig");
pub const gdt = @import("arch/gdt.zig");
pub const paging = @import("arch/paging/paging.zig");

pub usingnamespace @import("arch/io.zig");
