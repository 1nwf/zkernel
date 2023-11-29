const mem = @import("../mem/mem.zig");
const PhysFrameAllocator = mem.pmm;
const std = @import("std");
const log = std.log;
const elf = std.elf;
const io = std.io;
const arch = @import("arch");
const paging = arch.paging;
const thread = arch.thread;
const Process = @import("process.zig");

const Self = @This();

var ACTIVE_PROCESS: ?*Process = null;

pub var launcher: Self = undefined;

phys_frame_allocator: *PhysFrameAllocator,
kernel_page_dir: *paging.PageDirectory,
kernel_regions: []const mem.MemoryRegion,

pub fn init(
    phys_frame_allocator: *PhysFrameAllocator,
    kernel_page_dir: *paging.PageDirectory,
    kernel_regions: []const mem.MemoryRegion,
) Self {
    launcher = .{
        .phys_frame_allocator = phys_frame_allocator,
        .kernel_page_dir = kernel_page_dir,
        .kernel_regions = kernel_regions,
    };
    return launcher;
}

pub fn runProgram(self: *Self, bin: []u8) !void {
    var process = Process.init();
    for (self.kernel_regions) |region| {
        process.page_dir.mapRegions(region.start, region.start, region.size);
    }
    process.page_dir.load();

    var stream = io.fixedBufferStream(bin);
    const header = elf.Header.read(&stream) catch @panic("");

    const shdr_off: usize = @intCast(header.shoff);
    const shdr: [*]elf.Elf32_Shdr = @alignCast(@ptrCast(&bin[shdr_off]));

    const strtab_shdr: *elf.Elf32_Shdr = @ptrCast(&shdr[header.shstrndx]);
    const strtab: [*]u8 = @ptrCast(&bin[strtab_shdr.sh_offset]);

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

pub fn destroyActiveProcess(self: *Self) void {
    ACTIVE_PROCESS = null;
    self.kernel_page_dir.load();
    if (ACTIVE_PROCESS) |p| {
        p.deinit();
    }
}
