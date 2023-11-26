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

export fn kmain(bootInfo: *boot.MultiBootInfo) noreturn {
    main(bootInfo) catch |e| {
        log.info("panic: {}", .{e});
    };
    arch.halt();
}

pub const std_options = struct {
    pub fn logFn(comptime _: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
        if (scope != .default) serial.write("{s}: ", .{@tagName(scope)});
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

    loadElf();
    run_userspace_fn(&vmm);
}

pub fn run_userspace_fn(vmm: *mem.vmm) void {
    const user_stack = 0x50000;
    var user_page_dir = vmm.page_directory.findDir(user_stack);
    user_page_dir.us = 1;
    vmm.page_directory.mapUserPage(user_stack, user_stack);
    arch.thread.enter_userspace(@intFromPtr(&user_func), user_stack + arch.paging.PAGE_SIZE);
}

pub noinline fn user_func() void {
    write_syscall("in userspace indeeeeeed");

    while (true) {}
}

pub fn write_syscall(str: []const u8) void {
    asm volatile (
        \\ xor %%eax, %%eax
        \\ int $48
        :
        : [value] "{ebx}" (&str),
    );
}

fn loadElf() void {
    const process = @import("process/process.zig");
    var file = @embedFile("userspace_programs/write.elf").*;
    process.loadFile(&file) catch unreachable;
    arch.halt();
}
