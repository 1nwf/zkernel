pub const Pixel = packed struct(u32) {
    b: u8 = 0,
    g: u8 = 0,
    r: u8 = 0,
    _: u8 = 0,
};

pub const FrameBuffer = struct {
    ptr: [*]Pixel,
    width: u16,
    height: u16,
};

pub var framebuffer: FrameBuffer = undefined;
