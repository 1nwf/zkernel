const std = @import("std");
const Allocator = std.mem.Allocator;
const Error = Allocator.Error;

const BumpAlloc = @This();

heap_start: usize,
heap_end: usize,
next: usize,
allocations: usize = 0,

pub fn init(heap_start: usize, heap_size: usize) BumpAlloc {
    return BumpAlloc{ .heap_start = heap_start, .heap_end = heap_start + heap_size, .next = heap_start };
}

pub fn alloc(self: *BumpAlloc, comptime T: type, value: T) Error!*T {
    const size: usize = @sizeOf(T);

    const start_addr: *T = @ptrFromInt(self.next);
    const end_addr = @intFromPtr(start_addr) + size;

    if (end_addr > self.heap_end) {
        return Error.OutOfMemory;
    }
    self.next = end_addr;

    self.allocations += 1;
    start_addr.* = value;

    return start_addr;
}

pub fn free(self: *BumpAlloc) void {
    self.allocations -= 1;
    if (self.allocations == 0) {
        self.next = self.heap_start;
    }
}
