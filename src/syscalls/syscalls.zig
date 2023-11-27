const std = @import("std");
const log = std.log;

pub const Syscall = enum(u32) {
    Write = 0,
    fn fromInt(val: u32) ?@This() {
        return switch (val) {
            0...0 => @enumFromInt(val),
            else => null,
        };
    }
};

// %eax -> system call number
// %ebx -> arg 1
// %ecx -> arg 2
// %edx -> arg 3
// %esi -> arg 4
// %edi -> arg 5
pub noinline fn syscall_handler() void {
    const num: u32 = undefined;
    var arg1: u32 = undefined;
    var arg2: u32 = undefined;
    var arg3: u32 = undefined;
    var arg4: u32 = undefined;
    var arg5: u32 = undefined;
    asm volatile (""
        : [num] "={eax}" (num),
          [arg1] "={ebx}" (arg1),
          [arg2] "={ecx}" (arg2),
          [arg3] "={edx}" (arg3),
          [arg4] "={esi}" (arg4),
          [arg5] "={edi}" (arg5),
    );

    const syscall_num = Syscall.fromInt(num) orelse return;
    switch (syscall_num) {
        .Write => {
            const fmt: *[]const u8 = @ptrFromInt(arg1);
            write(fmt.*);
        },
    }
}

pub fn write(str: []const u8) void {
    log.info("{s}", .{str});
}