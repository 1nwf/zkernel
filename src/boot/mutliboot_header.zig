pub const BootDevice = extern struct {
    drive: u8,
    p1: u8,
    p2: u8,
    p3: u8,
};

pub const AoutSymbols = extern struct {
    tabsize: u32,
    strsize: u32,
    addr: u32,
    reserved: u32,
};
pub const ElfSymbols = extern struct {
    num: u32,
    size: u32,
    addr: u32,
    shndx: u32,
};

const ColorInfoPalette = extern struct {
    addr: u32,
    num_colors: u16,
};
const ColorInfoRgb = extern struct {
    red_field_pos: u8,
    red_mask_size: u8,
    green_field_pos: u8,
    green_mask_size: u8,
    blue_field_pos: u8,
    blue_mask_size: u8,
};

const ColorInfo = extern union {
    pallete: ColorInfoPalette,
    rgb: ColorInfoRgb,
};

const Symbols = extern union {
    aout_sym: AoutSymbols,
    elf_sec: ElfSymbols,
};

const FramebufferTable = extern struct {
    addr: u64,
    pitch: u32,
    width: u32,
    height: u32,
    bpp: u8,
    type: u8,
    color_info: ColorInfo,
};

pub const MultiBootInfo = extern struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: BootDevice,
    cmdline: u32,

    mods_count: u32,
    mods_addr: u32,
    symbols: Symbols,

    mmap_length: u32,
    mmap_addr: [*]MemMapEntry,

    drives_length: u32,
    drives_addr: u32,

    config_table: u32,

    boot_loader_name: [*:0]const u8,

    apm_table: u32,

    vbe_control_info: u32,
    vbe_mode_info: u32,
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_off: u16,
    vbe_interface_len: u16,

    framebuffer_table: FramebufferTable,
};

pub const MemMapEntry = extern struct {
    size: u32,
    base_addr: u64,
    length: u64,
    type: MemType,
};

pub const MemType = enum(u32) {
    Available = 1,
    Reserved,
    ACPI_Reclaimable,
    NVS,
    BadRam,
};
