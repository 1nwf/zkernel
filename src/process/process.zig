const std = @import("std");
const log = std.log;
const elf = std.elf;
const io = std.io;
const arch = @import("arch");
const paging = arch.paging;
const thread = arch.thread;
const mem = @import("../mem/mem.zig");

extern const kernel_start: usize;
extern const kernel_end: usize;

var kernel_memory_region: mem.MemoryRegion = undefined;

pub fn setKernelRegion() void {
    kernel_memory_region = mem.MemoryRegion.init(@intFromPtr(&kernel_start), @intFromPtr(&kernel_end) - @intFromPtr(&kernel_start));
}

page_dir: paging.PageDirectory align(paging.PAGE_SIZE),

const Self = @This();

fn init() Self {
    var page_dir = paging.PageDirectory.init();
    page_dir.mapRegions(kernel_memory_region.start, kernel_memory_region.start, kernel_memory_region.size);
    return .{ .page_dir = page_dir };
}

pub fn run_user_program(buff: []u8) !void {
    var stream = io.fixedBufferStream(buff);
    const header = elf.Header.read(&stream) catch @panic("");

    const shdr_off: usize = @intCast(header.shoff);
    const shdr: [*]elf.Elf32_Shdr = @alignCast(@ptrCast(&buff[shdr_off]));

    const strtab_shdr: *elf.Elf32_Shdr = @ptrCast(&shdr[header.shstrndx]);
    const strtab: [*]u8 = @ptrCast(&buff[strtab_shdr.sh_offset]);
    var process = init();
    process.page_dir.load();
    for (1..header.shnum) |idx| { // skip null section
        const s = shdr[idx];
        const s_name: [*:0]u8 = @ptrCast(&strtab[s.sh_name]);
        _ = s_name;
        if (s.sh_addr != 0 and s.sh_size != 0) {
            const aligned_addr = std.mem.alignBackward(usize, s.sh_addr, paging.PAGE_SIZE);
            const src = buff[s.sh_offset .. s.sh_offset + s.sh_size];
            const ssize = s.sh_size + (s.sh_addr - aligned_addr);
            process.page_dir.mapRegions(aligned_addr, aligned_addr, ssize);
            const dst: [*]u8 = @ptrFromInt(s.sh_addr);
            @memcpy(dst, src);
        }
    }

    var stack: [1024]u8 = undefined;
    thread.enter_userspace(@intCast(header.entry), @intFromPtr(&stack));
}
