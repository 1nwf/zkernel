const std = @import("std");
const arch = @import("arch");
const writeln = @import("root").serial.writeln;
const deviceInfo = @import("devices.zig");
const ide = @import("ide.zig");
const log = std.log.scoped(.pci);

const CONFIG_ADDRESS = 0xCF8;
const CONFIG_DATA = 0xCFC;

const PciLocation = packed struct(u16) {
    function: u3,
    device: u5,
    bus: u8,

    const Self = @This();
    pub fn readConfig(self: Self, comptime reg: PciRegisters) reg.getWidth() {
        var addr: PciAddress = .{
            .register_offset = reg,
            .location = self,
        };
        return addr.configRead(reg.getWidth());
    }
};

const PciAddress = packed struct(u32) {
    register_offset: PciRegisters, // 64 32-bit registers
    location: PciLocation,
    _res: u7 = 0,
    enable: u1 = 1,

    fn asBits(self: @This()) u32 {
        return @bitCast(self);
    }

    const Self = @This();
    fn configRead(self: *Self, comptime size: type) size {
        arch.out(CONFIG_ADDRESS, self.asBits());
        return arch.in(CONFIG_DATA, size);
    }
};

// https://github.com/ZystemOS/pluto/blob/develop/src/kernel/arch/x86/pci.zig#L20
pub const PciRegisters = enum(u8) {
    VenderId = 0x00,
    DeviceId = 0x02,
    Command = 0x04,
    Status = 0x06,
    RevisionId = 0x08,
    ProgrammingInterface = 0x09,
    Subclass = 0x0A,
    ClassCode = 0x0B,
    CacheLineSize = 0x0C,
    LatencyTimer = 0x0D,
    HeaderType = 0x0E,
    BIST = 0x0F,

    // The next set of registers are for the 0x00 (standard) header.
    // This currently uses only the common registers above that are available to all header types.

    BaseAddr0 = 0x10,
    BaseAddr1 = 0x14,
    BaseAddr2 = 0x18,
    BaseAddr3 = 0x1C,
    BaseAddr4 = 0x20,
    BaseAddr5 = 0x24,
    CardbusCISPtr = 0x28,
    SubsystemVenderId = 0x2C,
    SubsystemId = 0x2E,
    ExpansionROMBaseAddr = 0x30,
    CapabilitiesPtr = 0x34,
    InterruptLine = 0x3C,
    InterruptPin = 0x3D,
    MinGrant = 0x3E,
    MaxLatency = 0x3F,

    pub fn getWidth(comptime pci_reg: PciRegisters) type {
        return switch (pci_reg) {
            .RevisionId, .ProgrammingInterface, .Subclass, .ClassCode, .CacheLineSize, .LatencyTimer, .HeaderType, .BIST, .InterruptLine, .InterruptPin, .MinGrant, .MaxLatency, .CapabilitiesPtr => u8,
            .VenderId, .DeviceId, .Command, .Status, .SubsystemVenderId, .SubsystemId => u16,
            .BaseAddr0, .BaseAddr1, .BaseAddr2, .BaseAddr3, .BaseAddr4, .BaseAddr5, .CardbusCISPtr, .ExpansionROMBaseAddr => u32,
        };
    }
};

pub fn init(allocator: std.mem.Allocator) !void {
    const devices = try getAllDevices(allocator);
    var ide_device: *Device = undefined;
    for (devices) |*d| {
        if (d.location.readConfig(.ClassCode) == 1 and d.location.readConfig(.Subclass) == 1) {
            ide_device = d;
        }

        const vendor = d.location.readConfig(.VenderId);
        const deviceid = d.location.readConfig(.DeviceId);
        const subsystem = d.location.readConfig(.SubsystemId);
        log.info("{s} - {x} -- {x} -- {}", .{ d.getTypeName(), vendor, deviceid, subsystem });
    }

    ide.init(ide_device);
}

pub const Device = struct {
    location: PciLocation,
    class: u8,
    subclass: u8,

    const Self = @This();
    fn getTypeName(self: *const Self) []const u8 {
        return deviceInfo.getDeviceType(self.class, self.subclass);
    }
};

fn getAllDevices(allocator: std.mem.Allocator) ![]Device {
    const readFunction = struct {
        fn readFunction(func: u8, dev: u8, bus: u8) ?Device {
            const loc = PciLocation{ .function = @intCast(func), .device = @intCast(dev), .bus = @intCast(bus) };
            const class = loc.readConfig(.ClassCode);
            const subclass = loc.readConfig(.Subclass);
            if (class == 0xff) {
                return null;
            }
            return Device{ .location = loc, .class = class, .subclass = subclass };
        }
    }.readFunction;

    var devices = std.ArrayList(Device).init(allocator);
    var bus: u8 = 0;
    while (bus < 255) : (bus += 1) {
        var dev: u8 = 0;
        while (dev < 31) : (dev += 1) {
            var func: u8 = 0;
            const pci_dev = readFunction(func, dev, bus) orelse continue;
            try devices.append(pci_dev);
            if (pci_dev.location.readConfig(.HeaderType) == 0x80) {
                while (func < 8) : (func += 1) {
                    try devices.append(readFunction(func, dev, bus) orelse continue);
                }
            }
        }
    }
    return try devices.toOwnedSlice();
}
