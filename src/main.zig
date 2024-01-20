const std = @import("std");
const log = std.log.scoped(.default);

const arch = @import("arch");
const serial = arch.serial;
const vga = @import("drivers/vga.zig");
const gdt = arch.gdt;

const int = @import("interrupts/interrupts.zig");
const timer = @import("interrupts/timer.zig");
const heap = @import("heap/heap.zig");
const pg = arch.paging;
const multiboot = @import("boot/mutliboot_header.zig");
const pci = @import("drivers/pci/pci.zig");
const debug = @import("debug/debug.zig");

const mem = @import("mem/mem.zig");
const rtl8139 = @import("drivers/nic/rtl8139.zig");
const net = @import("net/net.zig");
const ProcessLauncher = @import("process/launcher.zig");
const process_scheduler = @import("process/scheduler.zig");

export fn kmain(boot_info: *multiboot.BootInfo) noreturn {
    log.info("boot info: 0x{x}", .{@intFromPtr(boot_info)});
    main(boot_info) catch |e| {
        log.info("panic: {}", .{e});
    };
    arch.halt();
}

pub const std_options = struct {
    pub fn logFn(comptime _: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
        if (scope != .default) serial.write("[{s}] ", .{@tagName(scope)});
        serial.writeln(format, args);
    }
};

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    serial.writeln("panic: {s}", .{msg});
    debug.printStackTrace();
    arch.halt();
}

extern const kernel_start: usize;
extern const kernel_end: usize;

var kernel_page_dir: pg.PageDirectory align(pg.PAGE_SIZE) = pg.PageDirectory.init();
var buffer: [1024 * 1024]u8 = undefined;

pub const os = struct {
    pub const heap = struct {
        pub const page_allocator: std.mem.Allocator = undefined;
    };
    pub const system = struct {};
};

fn main(boot_info: *multiboot.BootInfo) !void {
    var fixed_allocator = std.heap.FixedBufferAllocator.init(&buffer);
    var allocator = fixed_allocator.allocator();
    gdt.init();
    int.init();
    serial.init();
    vga.init(.{ .bg = .LightRed }, .Underline);

    const mem_map = try boot_info.get(.Mmap);
    const reserved_mem_regions = [_]mem.MemoryRegion{
        mem.MemoryRegion.init(@intFromPtr(&kernel_start), @intFromPtr(&kernel_end) - @intFromPtr(&kernel_start)),
        mem.MemoryRegion.init(0xb8000, 25 * 80), // frame buffer
    };

    var pmm = try mem.pmm.init(mem_map.entries(), allocator, &reserved_mem_regions);
    var vmm = try mem.vmm.init(&kernel_page_dir, &pmm, &reserved_mem_regions, allocator);
    _ = vmm;

    const pci_devices = try pci.init(allocator);
    const nic_pci_dev = pci_devices.find(0x10ec, 0x8139) orelse @panic("nic not found");
    var nic = (try rtl8139.init(nic_pci_dev)).setNic();
    nic.dhcp_init(allocator);

    try process_scheduler.init(allocator);

    var process_launcher = ProcessLauncher.init(&pmm, &kernel_page_dir, &reserved_mem_regions);
    runUserspaceProgram(process_launcher, allocator);
}

fn print_res(data: anytype) void {
    inline for (std.meta.fields(@TypeOf(data))) |f| {
        switch (@typeInfo(f.type)) {
            .Int => log.info("{s}: {x}", .{ f.name, @field(data, f.name) }),
            .Enum => log.info("{s}: {}", .{ f.name, @field(data, f.name) }),
            .Struct => print_res(@field(data, f.name)),
            else => {},
        }
    }
}

fn send_test_arp_packet(nic: *net.Nic) !void {
    const host_ip = [_]u8{ 192, 168, 1, 115 }; // vm ip address
    const target_ip = [_]u8{ 192, 168, 1, 1 };
    const packet = net.arp.Packet(.Ethernet, .IPv4).initRequest(nic.mac_address, host_ip, target_ip);
    const res = try nic.send_arp(packet, .{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff });
    if (res) |data| {
        const value = net.bigEndianToStruct(net.ethernet_frame.Frame(@TypeOf(packet)), data);
        log.info("value: {}", .{value});
    }
}

fn send_test_udp_packet(nic: *net.Nic) !void {
    const dhcp_header = net.dhcp.discoverPacket(nic.mac_address);
    const packet = net.udp.Datagram(@TypeOf(dhcp_header)).init(68, 67, dhcp_header);
    const data = nic.make_udp_packet(@TypeOf(dhcp_header), packet, .{ 0, 0, 0, 0 }, .{ 0xff, 0xff, 0xff, 0xff });
    try nic.transmit_packet(&data);
}

fn runUserspaceProgram(launcher: *ProcessLauncher, allocator: std.mem.Allocator) void {
    var file1 = @embedFile("userspace_programs/write.elf").*;
    var file2 = @embedFile("userspace_programs/yeild.elf").*;
    launcher.runProgram(allocator, &file1) catch unreachable;
    launcher.runProgram(allocator, &file2) catch unreachable;
}
