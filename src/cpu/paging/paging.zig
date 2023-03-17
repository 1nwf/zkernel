pub fn enable_paging() void {
    asm volatile (
        \\ mov %%cr0, %%eax
        \\ mov $0x1, %%edx
        \\ shl $31, %%edx
        \\ or %%edx, %%eax
        \\ mov %%eax, %%cr0
    );
}

pub fn isEnabled() bool {
    var cr0: u32 = 0;
    asm volatile (
        \\ mov %%cr0, %[cr0]
        : [cr0] "={eax}" (cr0),
    );

    return (cr0 >> 31) == 1;
}
