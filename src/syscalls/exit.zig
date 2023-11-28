const arch = @import("arch");

pub fn exit() void {
    // TODO: free active process resources
    arch.halt();
}
