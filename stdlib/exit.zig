const Syscalls = @import("syscalls").Syscall;
pub fn exit() void {
    asm volatile (
        \\ int $0x30
        :
        : [_] "{eax}" (Syscalls.Exit),
    );
}
