const arch = @import("arch");
const process = @import("../process/process.zig");

pub fn exit() void {
    process.destroyActiveProcess();
    arch.halt();
}
