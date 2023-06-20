const Entry = struct {
    start: u32,
    size: u32,
    regionType: RegionType,
    fn init(start: u32, size: u32, regionType: RegionType) Entry {
        return Entry{ .start = start, .size = size, .regionType = regionType };
    }
};

const RegionType = enum {
    Kernel,
    Used,
    Available,
};

pub const MemMapEntry = extern struct {
    base: u64,
    length: u64,
    type: u32,
    acpi: u32,
};
