const std = @import("std");
const Rsdt = @import("acpi.zig").Rsdt;

pub const TagType = enum(u32) {
    End = 0,
    Cmdline,
    BootLoaderName,
    Module,
    MemInfo,
    Bootdev,
    Mmap,
    Vbe,
    Framebuffer,
    ElfSections,
    Apm,
    Efi32,
    Efi64,
    Smbios,
    AcpiV1,
    AcpiV2,
    Network,
    EfiMmap,
    EfiBs,
    Efi32Ih,
    Efi64Ih,
    LoadBaseAddr,
};

pub const BootInfo = packed struct {
    size: u32,
    reserved: u32,

    const Self = @This();

    fn tagType(comptime tag_type: TagType) type {
        return switch (tag_type) {
            .Mmap => MemMap,
            .MemInfo => MemInfo,
            .AcpiV1 => Rsdp,
            else => @compileError("invalid tag type"),
        };
    }

    pub fn get(self: *Self, comptime tag_type: TagType) !*tagType(tag_type) {
        var ptr = @as([*]u8, @ptrCast(self)) + 8;
        var tag: *TagInfo = @alignCast(@ptrCast(ptr));
        while (tag.type != .End) : (tag = @ptrCast(@alignCast(ptr))) {
            if (tag.type == tag_type) {
                return @ptrCast(tag);
            }
            ptr += std.mem.alignForward(usize, tag.size, 8);
        }
        return error.InvalidTagType;
    }
};

pub const TagInfo = packed struct {
    type: TagType,
    size: u32,
};

pub const MemType = enum(u32) {
    Available = 1,
    Reserved,
    ACPI_Reclaimable,
    NVS,
    BadRam,
};

pub const MemMapEntry = packed struct {
    base_addr: u64,
    len: u64,
    type: MemType,
    reserved: u32,
};

const MemMap = packed struct {
    tag: TagInfo,
    entry_size: u32,
    entry_version: u32,

    const Self = @This();
    pub fn entries(self: *Self) []MemMapEntry {
        const bytes: [*]u8 = @ptrCast(self);
        return @alignCast(std.mem.bytesAsSlice(MemMapEntry, bytes[16..self.tag.size]));
    }
};

const MemInfo = packed struct {
    tag: TagInfo,
    mem_lower: u32,
    mem_upper: u32,
};

const Rsdp = extern struct {
    tag: TagInfo align(1),
    signature: [8]u8,
    checksum: u8,
    oem_id: [6]u8,
    revision: u8,
    rsdt_ptr: *Rsdt align(1),

    const Self = @This();
    pub fn validate(self: *const Self) !void {
        if (!std.mem.eql(u8, &self.signature, "RSD PTR ")) {
            return error.InvalidSignature;
        }
        const bytes = std.mem.toBytes(self.*);
        var sum: u8 = 0;
        for (bytes[8..]) |b| {
            sum +%= b;
        }
        if (sum != 0) {
            return error.InvalidChecksum;
        }
    }
};
