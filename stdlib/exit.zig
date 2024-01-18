pub fn exit() void {
    asm volatile (
        \\ mov $1, %%eax
        \\ int $0x30
        ::: "eax");
}
