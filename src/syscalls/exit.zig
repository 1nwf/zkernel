const arch = @import("arch");
const process_launcher = @import("../process/launcher.zig");

pub fn exit() void {
    process_launcher.launcher.destroyActiveProcess();
    arch.halt();
}
