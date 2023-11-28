const std = @import("std");
const log = std.log;
const elf = std.elf;
const io = std.io;
const arch = @import("arch");
const paging = arch.paging;
const thread = arch.thread;
const mem = @import("../mem/mem.zig");

var ACTIVE_PROCESS: ?*Self = null;

extern const kernel_start: usize;
extern const kernel_end: usize;

var kernel_memory_regions: []const mem.MemoryRegion = undefined;
var kernel_page_dir: *paging.PageDirectory = undefined;

pub fn setKernelRegion(kernel_pgdir: *paging.PageDirectory, kernel_regions: []const mem.MemoryRegion) void {
    kernel_memory_regions = kernel_regions;
    kernel_page_dir = kernel_pgdir;
}

page_dir: paging.PageDirectory align(paging.PAGE_SIZE),

const Self = @This();

fn init() Self {
    var page_dir = paging.PageDirectory.init();
    for (kernel_memory_regions) |region| {
        page_dir.mapRegions(region.start, region.start, region.size);
    }
    return .{ .page_dir = page_dir };
}

pub fn runUserProgram(bin: []u8) !void {
    var stream = io.fixedBufferStream(bin);
    const header = elf.Header.read(&stream) catch @panic("");

    const shdr_off: usize = @intCast(header.shoff);
    const shdr: [*]elf.Elf32_Shdr = @alignCast(@ptrCast(&bin[shdr_off]));

    const strtab_shdr: *elf.Elf32_Shdr = @ptrCast(&shdr[header.shstrndx]);
    const strtab: [*]u8 = @ptrCast(&bin[strtab_shdr.sh_offset]);
    var process = init();
    process.page_dir.load();
    for (1..header.shnum) |idx| { // skip null section
        const s = shdr[idx];
        const s_name: [*:0]u8 = @ptrCast(&strtab[s.sh_name]);
        _ = s_name;
        if (s.sh_addr != 0 and s.sh_size != 0) {
            const aligned_addr = std.mem.alignBackward(usize, s.sh_addr, paging.PAGE_SIZE);
            const src = bin[s.sh_offset .. s.sh_offset + s.sh_size];
            const ssize = s.sh_size + (s.sh_addr - aligned_addr);
            process.page_dir.mapUserRegions(aligned_addr, aligned_addr, ssize);
            const dst: [*]u8 = @ptrFromInt(s.sh_addr);
            @memcpy(dst, src);
        }
    }

    var stack: [paging.PAGE_SIZE]u8 align(paging.PAGE_SIZE) = undefined;
    process.page_dir.mapUserRegions(@intFromPtr(&stack), 0, paging.PAGE_SIZE);
    ACTIVE_PROCESS = &process;
    thread.enter_userspace(@intCast(header.entry), paging.PAGE_SIZE);
}

pub fn deinit(self: *Self) void {
    ACTIVE_PROCESS = null;
    kernel_page_dir.load();
    self.page_dir.deinit();
}

pub fn destroyActiveProcess() void {
    if (ACTIVE_PROCESS) |p| {
        p.deinit();
    }
}
