const exit = @import("exit.zig").exit;

export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\ call main
    );

    @call(.always_inline, exit, .{});
}
