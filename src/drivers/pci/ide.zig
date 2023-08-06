const pci = @import("pci.zig");
const arch = @import("arch");
const writeln = @import("root").serial.writeln;

const Status = enum(u8) {
    Busy = 0x80, // Busy
    Ready = 0x40, // Drive ready
    WriteFault = 0x20, // Drive write fault
    SeekComplete = 0x10, // Drive seek complete
    RequestReady = 0x08, // Data request ready
    CorrectedData = 0x04, // Corrected data
    Index = 0x02, // Index
    Error = 0x01, // Error
};

const Error = enum(u8) {
    BadBlock = 0x80, // Bad block
    UncorrectableData = 0x40, // Uncorrectable data
    MediaChanged = 0x20, // Media changed
    IdNotFound = 0x10, // ID mark not found
    MediaChangeRequest = 0x08, // Media change request
    Abort = 0x04, // Command aborted
    Track0NotFound = 0x02, // Track 0 not found
    NoAddressMark = 0x01, // No address mark
};

const Commands = enum(u8) {
    ATA_CMD_READ_PIO = 0x20,
    ATA_CMD_READ_PIO_EXT = 0x24,
    ATA_CMD_READ_DMA = 0xC8,
    ATA_CMD_READ_DMA_EXT = 0x25,
    ATA_CMD_WRITE_PIO = 0x30,
    ATA_CMD_WRITE_PIO_EXT = 0x34,
    ATA_CMD_WRITE_DMA = 0xCA,
    ATA_CMD_WRITE_DMA_EXT = 0x35,
    ATA_CMD_CACHE_FLUSH = 0xE7,
    ATA_CMD_CACHE_FLUSH_EXT = 0xEA,
    ATA_CMD_PACKET = 0xA0,
    ATA_CMD_IDENTIFY_PACKET = 0xA1,
    ATA_CMD_IDENTIFY = 0xEC,
};

const Registers = enum(u16) {
    Data = 0x0,
    Error,
    Features,
    SecCount0,
    LBA0,
    LBA1,
    LBA2,
    HDDevSel,
    Command,
    Status,
    SecCount1,
    LBA3,
    LBA4,
    LBA5,
    Control,
    AltStatus,
    DevAddress,
};

const Channel = struct {
    base: u16,
    control: u16,
    bmide: u16, // bust master ide

    const Self = @This();
};

pub fn init(dev: pci.Device) void {
    const bar0 = dev.location.readConfig(.BaseAddr0);
    const bar1 = dev.location.readConfig(.BaseAddr1);
    const bar2 = dev.location.readConfig(.BaseAddr2);
    const bar3 = dev.location.readConfig(.BaseAddr3);
    const bar4 = dev.location.readConfig(.BaseAddr4);

    const progif = dev.location.readConfig(.ProgrammingInterface);
    writeln("progif: {b}", .{progif});

    var primary = Channel{
        .base = if (bar0 != 0) @intCast(bar0) else 0x1f0,
        .control = if (bar1 != 0) @intCast(bar1) else 0x1F7,
        .bmide = @intCast(bar4),
    };
    _ = primary;
    const secondary = Channel{
        .base = if (bar2 != 0) @intCast(bar2) else 0x1f0,
        .control = if (bar3 != 0) @intCast(bar3) else 0x1F7,
        .bmide = @intCast(bar4 + 8),
    };

    _ = secondary;
}
