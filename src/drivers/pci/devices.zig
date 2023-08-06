pub const DeviceType = enum(u8) {
    storage = 1,
    network,
    display,
    bridge = 6,

    const Self = @This();

    pub fn fromInt(num: u8) !Self {
        return switch (num) {
            1...3, 6 => @enumFromInt(num),
            else => error.InvalidNum,
        };
    }
};

pub fn getDeviceType(class: u8, subclass: u8) []const u8 {
    return switch (class) {
        0x0 => switch (subclass) {
            0 => "Non-VGA-Compatible Unclassified Device",
            1 => "VGA-Compatible Unclassified Device",
            else => "Unknown",
        },
        0x1 => switch (subclass) {
            0x0 => "SCSI Bus Controller",
            0x1 => "IDE Controller",
            0x2 => "Floppy Disk Controller",
            0x3 => "IPI Bus Controller",
            0x4 => "RAID Controller",
            0x5 => "ATA Controller",
            0x6 => "Serial ATA Controller",
            0x7 => "Serial Attached SCSI Controller",
            0x8 => "Non-Volatile Memory Controller",
            else => "Mass Storage Controller",
        },
        0x2 => switch (subclass) {
            0x0 => "Ethernet Controller",
            0x1 => "Token Ring Controller",
            0x2 => "FDDI Controller",
            0x3 => "ATM Controller",
            0x4 => "ISDN Controller",
            0x5 => "WorldFip Controller",
            0x6 => "PICMG 2.14 Multi Computing Controller",
            0x7 => "Infiniband Controller",
            0x8 => "Fabric Controller",
            else => "Network Controller",
        },
        0x3 => switch (subclass) {
            0x0 => "VGA Compatible Controller",
            0x1 => "XGA Controller",
            0x2 => "3D Controller (Not VGA-Compatible)",
            else => "Display Controller",
        },
        0x4 => switch (subclass) {
            0x0 => "Multimedia Video Controller",
            0x1 => "Multimedia Audio Controller",
            0x2 => "Computer Telephony Device",
            0x3 => "Audio Device",
            else => "Multimedia Controller",
        },
        0x5 => switch (subclass) {
            0x0 => "RAM Controller",
            0x1 => "Flash Controller",
            else => "Memory Controller",
        },
        0x6 => switch (subclass) {
            0x0 => "Host Bridge",
            0x1 => "ISA Bridge",
            0x2 => "EISA Bridge",
            0x3 => "MCA Bridge",
            0x4 => "PCI-to-PCI Bridge",
            0x5 => "PCMCIA Bridge",
            0x6 => "NuBus Bridge",
            0x7 => "CardBus Bridge",
            0x8 => "RACEway Bridge",
            0x9 => "PCI-to-PCI Bridge",
            0xA => "InfiniBand-to-PCI Host Bridge",
            else => "Bridge",
        },
        else => "Unknown",
    };
}
