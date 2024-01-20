pub usingnamespace @import("write.zig");
pub usingnamespace @import("exit.zig");

pub fn yeild() void {
    asm volatile (
        \\ mov $3, %%eax
        \\ int $48
        ::: "eax");
}
