const std = @import("std");
const log = std.log.scoped(.net);
const pci = @import("../pci/pci.zig");
const paging = @import("arch").paging;

pub fn init(device: pci.Device) void {
    const features = device.location.readConfig(.VendorId);
    const status = device.location.readConfig(.Status);
    log.info("initializing virtio net driver: 0b{b} -- 0b{b}", .{ features, status });

    const bars = [6]u32{
        device.location.readConfig(.BaseAddr0),
        device.location.readConfig(.BaseAddr1),
        device.location.readConfig(.BaseAddr2),
        device.location.readConfig(.BaseAddr3),
        device.location.readConfig(.BaseAddr4),
        device.location.readConfig(.BaseAddr5),
    };

    const bar4 = device.get_bar(u64, 4);
    log.info("bar4: 0x{x} ", .{bar4});

    var cap = pci.Capabilities.init(device.location);
    while (cap.read()) |info| {
        log.info("info: {}", .{info});
        if (info.vendor == 0x9) {
            var virtio_cap = VirtioPciCap.init(&cap, info);
            const addr = bars[virtio_cap.bar] + virtio_cap.offset;
            log.info("0x{x} -- {}", .{ addr, virtio_cap });
        }
    }
}

const Buffer = struct {
    address: u64,
    length: u32,
    flags: u16,
    next: u16,
    const Self = @This();
    fn init() Self {
        return .{};
    }
};
const Available = struct { flags: u16, index: u16, ring: []u16, eventIndex: u16 };
const Used = struct { flags: u16, index: u16, ring: []struct { index: u32, length: u32 }, availEvent: u16 };
const VirtQueue = struct {
    const QueueSize = 1000;
    buffers: []Buffer,
    available: Available,
    used: Used,
};

const VirtioPciCap = struct {
    cap: pci.PciCap,
    cfg_type: u8,
    bar: u8,
    offset: u32,
    length: u32,

    const Self = @This();
    pub fn init(cap: *pci.Capabilities, base: pci.PciCap) Self {
        return .{
            .cap = base,
            .cfg_type = cap.readOffset(u8, 3),
            .bar = cap.readOffset(u8, 4),
            .offset = cap.readOffset(u32, 8),
            .length = cap.readOffset(u32, 12),
        };
    }

    fn parseType(self: *Self, addr: usize) void {
        _ = addr;
        if (self.cfg_type > 5) return;
        const cfg_type: ConfigType = @enumFromInt(self.cfg_type);
        switch (cfg_type) {
            .common => {},
            .notify => {},
            .isr => {},
            .device => {},
            .pci => {},
        }
    }
};

const ConfigType = enum(u8) {
    common = 1,
    notify,
    isr,
    device,
    pci,
};

const CommonConfig = extern struct {
    device_feature_select: u32,
    device_feature: u32,
    driver_feature_select: u32,
    driver_feature: u32,
    msix_config: u16,
    num_queues: u16,
    device_status: u8,
    config_generation: u8,
    queue_select: u16,
    queue_size: u16,
    queue_msix_vector: u16,
    queue_enable: u16,
    queue_notify_off: u16,
    queue_desc: u64,
    queue_driver: u64,
    queue_device: u64,
};

const NotifyConfig = struct {
    cap: VirtioPciCap,
    notify_off_multipller: u32,
};

const IsrConfig = struct {};
