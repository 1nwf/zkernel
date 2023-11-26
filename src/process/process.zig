const std = @import("std");
const log = std.log;
const elf = std.elf;
const io = std.io;

pub fn loadFile(buff: []u8) !void {
    var stream = io.fixedBufferStream(buff);
    const header = elf.Header.read(&stream) catch @panic("");

    const shdr_off: usize = @intCast(header.shoff);
    const shdr: [*]elf.Elf32_Shdr = @alignCast(@ptrCast(&buff[shdr_off]));

    const strtab_shdr: *elf.Elf32_Shdr = @ptrCast(&shdr[header.shstrndx]);
    const strtab: [*]u8 = @ptrCast(&buff[strtab_shdr.sh_offset]);
    for (1..header.shnum) |idx| {
        const s = shdr[idx];
        const name: [*:0]u8 = @ptrCast(&strtab[s.sh_name]);
        log.info("{} -- {s}", .{ shdr[idx].sh_type, name });
    }

    log.info("entry: 0x{x}", .{header.entry});
}

test {
    var arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var alloc = arena_alloc.allocator();
    var ptr = try alloc.alloc(u8, 100);

    // var slice: [*]u8 = @ptrCast(ptr);
    loadFile(ptr);
}
