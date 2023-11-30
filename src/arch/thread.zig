const gdt = @import("gdt.zig");

pub fn enter_userspace(ip: u32, stack: u32) noreturn {
    asm volatile (
        \\ cli
        \\ mov %[user_data], %%dx
        \\ mov %%dx, %%ds
        \\ mov %%dx, %%gs
        \\ mov %%dx, %%es
        \\ mov %%dx, %%fs 
        \\
        \\ push %[user_data]
        \\ push %[stack]
        \\ pushf
        \\
        \\ push %[user_code]
        \\ push %[ip]
        \\ iret
        :
        : [user_code] "i" (gdt.user_code_offset | 3),
          [user_data] "i" (gdt.user_data_offset | 3),
          [stack] "r" (stack),
          [ip] "r" (ip),
        : "edx"
    );

    unreachable;
}
