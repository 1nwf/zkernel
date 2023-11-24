const ethernet = @import("ethernet_frame.zig");
const arp = @import("protocols/arp.zig");
const utils = @import("utils.zig");

test {
    _ = arp;
    _ = ethernet;
    _ = utils;
}
