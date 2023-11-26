pub fn write(str: []const u8) void {
    asm volatile (
        \\ xor %%eax, %%eax
        \\ int $48
        :
        : [value] "{ebx}" (&str),
    );
}
