const gdt = @import("gdt.zig");
const TSSEntry = packed struct {
    prev_tss: u32, // The previous TSS - with hardware task switching these form a kind of backward linked list.
    esp0: u32, // The stack pointer to load when changing to kernel mode.
    ss0: u32, // The stack segment to load when changing to kernel mode.
    // Everything below here is unused.
    esp1: u32 = 0, // esp and ss 1 and 2 would be used when switching to rings 1 or 2,
    ss1: u32 = 0,
    esp2: u32 = 0,
    ss2: u32 = 0,
    cr3: u32 = 0,
    eip: u32 = 0,
    eflags: u32 = 0,
    eax: u32 = 0,
    ecx: u32 = 0,
    edx: u32 = 0,
    ebx: u32 = 0,
    esp: u32 = 0,
    ebp: u32 = 0,
    esi: u32 = 0,
    edi: u32 = 0,
    es: u32 = 0,
    cs: u32 = 0,
    ss: u32 = 0,
    ds: u32 = 0,
    fs: u32 = 0,
    gs: u32 = 0,
    ldt: u32 = 0,
    trap: u16 = 0,
    iomap_base: u16 = 0,
};

pub var entry: TSSEntry = undefined;
extern const kernel_stack_end: u32;
pub var gdt_entry: gdt.Entry = undefined;

pub fn init() void {
    entry = TSSEntry{
        .prev_tss = 0,
        .esp0 = @intFromPtr(&kernel_stack_end),
        .cs = 0x8,
        .ss0 = 0x10,
        .es = 0x10,
        .ss = 0x10,
        .ds = 0x10,
        .fs = 0x10,
        .gs = 0x10,
    };

    const base: u32 = @intFromPtr(&entry);
    const limit: u20 = @sizeOf(TSSEntry);
    gdt_entry = gdt.Entry.init(base, limit, .{
        .access = 1,
        .rw = 0,
        .dc = 0,
        .exec = 1,
        .type = 0,
        .dpl = 0,
        .present = 1,
    }, .{
        .granularity = 0,
        .long_mode = 0,
        .is_32bit = 0,
    });
}

pub fn flush_tss(comptime tss_offset: u16) void {
    asm volatile (
        \\ mov %[off], %%ax
        \\ ltr %%ax
        \\
        :
        : [off] "i" (tss_offset),
    );
}
