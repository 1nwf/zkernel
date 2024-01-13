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
const boot = @import("boot/mutliboot_header.zig");
const pci = @import("drivers/pci/pci.zig");
const debug = @import("debug/debug.zig");

const mem = @import("mem/mem.zig");
const virt_mem = arch.virt_mem;
const rtl8139 = @import("drivers/nic/rtl8139.zig");
const net = @import("net/net.zig");

export fn kmain(bootInfo: *boot.MultiBootInfo) noreturn {
    main(bootInfo) catch |e| {
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

fn main(bootInfo: *boot.MultiBootInfo) !void {
    var fixed_allocator = std.heap.FixedBufferAllocator.init(&buffer);
    var allocator = fixed_allocator.allocator();
    gdt.init();
    int.init();
    serial.init();
    vga.init(.{ .bg = .LightRed }, .Underline);

    vga.writeln("bootloader name: {s}", .{bootInfo.boot_loader_name});
    vga.writeln("header flags: 0b{b}", .{bootInfo.flags});

    const mem_map_length = bootInfo.mmap_length / @sizeOf(boot.MemMapEntry);
    vga.writeln("mmap length: {}", .{mem_map_length});

    const mem_map: []boot.MemMapEntry = bootInfo.mmap_addr[0..mem_map_length];

    var reserved_mem_regions = [_]mem.MemoryRegion{
        mem.MemoryRegion.init(@intFromPtr(&kernel_start), @intFromPtr(&kernel_end) - @intFromPtr(&kernel_start)),
        mem.MemoryRegion.init(0xb8000, 25 * 80), // frame buffer
    };

    var pmm = try mem.pmm.init(mem_map, allocator);
    var vmm = try mem.vmm.init(&kernel_page_dir, &pmm, &reserved_mem_regions, allocator);
    _ = vmm;

    const pci_devices = try pci.init(allocator);
    const nic_pci_dev = pci_devices.find(0x10ec, 0x8139) orelse @panic("nic not found");
    var nic = (try rtl8139.init(nic_pci_dev)).setNic();
    nic.dhcp_init(allocator);
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
