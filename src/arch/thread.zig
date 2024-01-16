const gdt = @import("gdt.zig");

pub export fn launch_thread(ctx: *const Context) noreturn {
    asm volatile (
        \\ cli
        \\ mov %[context], %%esp
        \\
        \\ pop %%edi
        \\ pop %%esi
        \\ pop %%ebp
        \\ pop %%ebx
        \\ pop %%edx
        \\ pop %%ecx
        \\ pop %%eax
        \\
        \\ iret
        :
        : [context] "{edx}" (@intFromPtr(ctx)),
    );

    unreachable;
}

pub const Context = extern struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,
    // cpu pushed values
    eip: u32, // instruction pointer
    cs: u32, // code segment
    eflags: u32, // cpu flags
    esp: u32, // stack pointer of interrupt code
    ss: u32, // stack segment

    pub fn init_user_context(eip: u32, esp: u32) Context {
        return .{
            .edi = 0,
            .esi = 0,
            .ebp = 0,
            .ebx = 0,
            .edx = 0,
            .ecx = 0,
            .eax = 0,
            .eip = eip,
            .cs = gdt.user_code_offset | 3,
            .eflags = 0x200, // set interrupt enable bit
            .esp = esp,
            .ss = gdt.user_data_offset | 3,
        };
    }
};
