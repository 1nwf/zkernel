pub const serial = @import("arch/serial.zig");
pub const gdt = @import("arch/gdt.zig");
pub const paging = @import("arch/paging/paging.zig");
pub const thread = @import("arch/thread.zig");

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

pub fn interrupt_handler(comptime handler: fn (*thread.Context) callconv(.C) usize) fn () callconv(.Naked) void {
    return struct {
        fn _fn() callconv(.Naked) void {
            asm volatile (
                \\ cli
                \\
                \\ push %%eax
                \\ push %%ecx
                \\ push %%edx
                \\ push %%ebx
                \\ push %%ebp
                \\ push %%esi
                \\ push %%edi
                \\ push %%esp
                \\
                // ":c" makes llvm print the symbol name
                \\ call %[handler:c] 
                \\ test %%eax, %%eax
                \\ jnz 1f
                \\ pop %%eax
                \\
                \\1:
                \\ mov %%eax, %%esp
                \\ pop %%edi
                \\ pop %%esi
                \\ pop %%ebp
                \\ pop %%ebx
                \\ pop %%edx
                \\ pop %%ecx
                \\ pop %%eax
                \\  
                \\ sti
                \\ iret
                :
                : [handler] "i" (handler),
            );
        }
    }._fn;
}
