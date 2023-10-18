pub const Access = packed struct {
    access: u1 = 0,
    rw: u1,
    dc: u1,
    exec: u1,
    type: u1, // 0 = system segment. 1 = code or data segment
    dpl: u2, // descriptor privelage level
    present: u1,

    const KernelCode = Access{ .present = 1, .dpl = 0, .type = 1, .exec = 1, .dc = 0, .rw = 1, .access = 0 };
    const KernelData = Access{ .present = 1, .dpl = 0, .type = 1, .exec = 0, .dc = 0, .rw = 1, .access = 0 };
    const UserCode = Access{ .present = 1, .dpl = 3, .type = 1, .exec = 1, .dc = 0, .rw = 1, .access = 0 };
    const UserData = Access{ .present = 1, .dpl = 3, .type = 1, .exec = 0, .dc = 0, .rw = 1, .access = 0 };
};

const Flags = packed struct {
    reserved: u1 = 0,
    // if set, defines if the segment is a 64-bit code segment
    long_mode: u1,
    // if set, defines if the segment is a 32-bit segment. else it is a 16-bit segment
    is_32bit: u1,
    // indicates how the limit value should be interpreted. if set, the limit is in 4 Kib blocks
    granularity: u1,
};

pub const Entry = packed struct {
    limit_low: u16,
    base_low: u24,
    access: Access,
    limit_high: u4,
    flags: Flags,
    base_high: u8,

    pub fn bits(self: Entry) u64 {
        return @as(u64, @bitCast(self));
    }

    pub fn empty() Entry {
        return @as(Entry, @bitCast(@as(u64, 0)));
    }

    fn init(base: u32, limit: u20, access: Access, flags: Flags) Entry {
        return Entry{
            .limit_low = @truncate(limit & 0xFFFF),
            .limit_high = @truncate(limit >> 16),
            .base_low = @truncate(base & ~@as(u32, (0xFF << 24))),
            .base_high = @truncate(base >> 24),
            .access = access,
            .flags = flags,
        };
    }
};

pub const KernelCodeSegment = Entry.init(0, 0xFFFFF, Access.KernelCode, .{ .is_32bit = 1, .long_mode = 0, .granularity = 1 });
pub const KernelDataSegment = Entry.init(0, 0xFFFFF, Access.KernelData, .{ .is_32bit = 1, .long_mode = 0, .granularity = 1 });

pub const UserCodeSegment = Entry.init(0, 0xFFFFF, Access.UserCode, .{ .is_32bit = 1, .long_mode = 0, .granularity = 1 });
pub const UserDataSegment = Entry.init(0, 0xFFFFF, Access.UserData, .{ .is_32bit = 1, .long_mode = 0, .granularity = 1 });

pub const GDT = [_]Entry{ Entry.empty(), KernelCodeSegment, KernelDataSegment, UserCodeSegment, UserDataSegment };

pub const GDTR = extern struct {
    size: u16,
    base: *const [5]Entry align(2),
    fn init(comptime base: *const [5]Entry, size: u16) GDTR {
        return GDTR{ .base = base, .size = size };
    }

    export fn load(self: *const GDTR) void {
        asm volatile (
            \\ cli
            \\ lgdt (%[addr])
            \\ sti
            :
            : [addr] "r" (self),
        );
    }
};

pub const gdtr: GDTR = GDTR.init(&GDT, @sizeOf(@TypeOf(GDT)) - 1);

pub fn init() void {
    gdtr.load();

    asm volatile (
        \\ mov $0x10, %%ax
        \\ mov %%ax, %%ds
        \\ mov %%ax, %%ss
        \\ mov %%ax, %%gs
        \\ mov %%ax, %%es
        \\ mov %%ax, %%fs
        \\ 
        \\ ljmp $0x08, $done
        \\ done:
    );
}

pub fn storedGDT() @TypeOf(GDT) {
    var ptr: GDTR = undefined;
    asm volatile (
        \\ sgdtl %[val]
        : [val] "=m" (ptr),
    );

    var data = @as(*@TypeOf(GDT), @ptrFromInt(ptr.base));
    return data.*;
}
