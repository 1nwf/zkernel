const std = @import("std");
const pg = @import("arch").paging;
const log = std.log;
const wait = @import("../interrupts/timer.zig").wait;
const AcpiSdtHeader = extern struct {
    signature: [4]u8,
    length: u32 align(1),
    revision: u8,
    checksum: u8,
    oem_id: [6]u8,
    oem_table_id: [8]u8,
    oem_revision: u32 align(1),
    creator_id: u32 align(1),
    creator_revision: u32 align(1),

    pub fn validate(self: *const @This()) !void {
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

pub const Rsdt = extern struct {
    header: AcpiSdtHeader,
    pointers: void,

    pub fn get_madt(self: *@This()) ?*align(1) Madt {
        const len: usize = (self.header.length - @sizeOf(AcpiSdtHeader)) / 4;
        var items: []align(1) *AcpiSdtHeader = undefined;
        items.ptr = @ptrCast(&self.pointers);
        items.len = len;
        for (items) |p| {
            if (std.mem.eql(u8, &p.signature, "APIC")) {
                return @ptrCast(p);
            }
        }

        return null;
    }
};

pub const Madt = extern struct {
    header: AcpiSdtHeader,
    local_apic_addr: u32,
    flags: u32,
    records: void,

    const EntryHeader = packed struct {
        entry_type: u8,
        length: u8,
    };
    const Self = @This();

    pub fn cpuCoreCount(self: *align(1) Self) u8 {
        var core_count: u8 = 0;
        const len = self.header.length - @sizeOf(Madt);
        var bytes: [*]u8 = @ptrCast(&self.records);
        for (0..len) |_| {
            const entry: *align(1) EntryHeader = @ptrCast(bytes);
            if (entry.entry_type == 0) { // Processor Local APIC
                core_count += 1;
            }
            bytes += entry.length;
        }
        return core_count;
    }
};

pub const LocalApic = packed struct {
    header: Madt.EntryHeader,
    acpi_id: u8,
    apic_id: u8,
    flags: u32,
};

pub fn cpuid() u8 {
    const ebx = asm volatile (
        \\ mov $1, %%ebx
        \\ cpuid
        : [out] "={ebx}" (-> u32),
    );
    return @intCast(ebx >> 24);
}

pub const Apic = struct {
    base: u32,

    // two 32-bit registers in the apic used for sending inter-process interrupts
    icr_low: *volatile u32,
    icr_high: *volatile u32,

    const Self = @This();

    pub fn init(base: u32) Self {
        pg.mapRegion(base, base, pg.PAGE_SIZE);

        return .{
            .base = base,
            .icr_low = @ptrFromInt(base + 0x300),
            .icr_high = @ptrFromInt(base + 0x310),
        };
    }

    fn set_ipi_dest(self: *Self, dest: u8) void {
        self.icr_high.* |= (@as(u32, dest) << 24);
    }

    fn send_init_ipi(self: *Self, cpu_id: u8) void {
        self.set_ipi_dest(cpu_id);
        const msg = InterruptMessage{
            .vector = 0,
            .delivery_mode = .Init,
            .destination_mode = .Physical,
            .level = .Assert,
            .trigger_mode = .Edge,
            .destination_shorthand = .None,
        };
        self.icr_low.* = msg.as_u32();
        self.ipi_wait_delivery();
    }

    fn ipi_wait_delivery(self: *Self) void {
        while ((self.icr_low.* >> 12) & 1 == 1) {}
    }

    fn send_startup_ipi(self: *Self, cpu_id: u8) void {
        self.set_ipi_dest(cpu_id);
        const msg = InterruptMessage{
            .vector = 8,
            .delivery_mode = .Startup,
            .destination_mode = .Physical,
            .level = .Assert,
            .trigger_mode = .Edge,
            .destination_shorthand = .None,
        };
        self.icr_low.* = msg.as_u32();
        wait(10);
    }

    fn send_deinit_ipi(self: *Self, cpu_id: u8) void {
        self.set_ipi_dest(cpu_id);
        const msg = InterruptMessage{
            .vector = 0,
            .delivery_mode = .Init,
            .destination_mode = .Physical,
            .level = .Deassert,
            .trigger_mode = .Edge,
            .destination_shorthand = .None,
        };
        self.icr_low.* = msg.as_u32();
        self.ipi_wait_delivery();
    }
    pub fn boot_cpus(self: *Self, cores: u8) void {
        for (1..cores) |core_id| {
            self.send_init_ipi(@intCast(core_id));
            self.send_startup_ipi(@intCast(core_id));
        }
    }
};

pub const DestinationShorthand = enum(u2) {
    None = 0,
    Self,
    AllIncludingSelf,
    AllExcludingSelf,
};

pub const DeliveryMode = enum(u3) {
    Fixed = 0,
    LowestPriority,
    Smi,
    Nmi = 4,
    Init,
    Startup,
};

pub const DestinationMode = enum(u1) {
    Physical = 0,
    Logical,
};

pub const DeliveryStatus = enum(u1) {
    Idle = 0,
    Pending,
};

pub const Level = enum(u1) {
    Deassert = 0,
    Assert,
};

pub const TriggerMode = enum(u1) {
    Edge = 0,
    Level,
};

pub const InterruptMessage = packed struct(u32) {
    vector: u8,
    delivery_mode: DeliveryMode,
    destination_mode: DestinationMode,
    _r1: u1 = 0,
    delivery_status: DeliveryStatus = .Idle,
    level: Level,
    trigger_mode: TriggerMode,
    _r2: u2 = 0,
    destination_shorthand: DestinationShorthand,
    _r3: u12 = 0,

    fn as_u32(self: *const @This()) u32 {
        return @bitCast(self.*);
    }
};
