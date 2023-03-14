const std = @import("std");
const BumpAlloc = @This();

heap_start: usize,
heap_end: usize,
next: usize,
allocations: usize = 0,

pub fn init(heap_start: usize, heap_size: usize) BumpAlloc {
    return BumpAlloc{ .heap_start = heap_start, .heap_end = heap_start + heap_size, .next = heap_start };
}

const AllocationError = error{OutOfMemory};

pub fn alloc(self: *BumpAlloc, comptime T: type, value: T) AllocationError!*T {
    var size: usize = @sizeOf(T);

    var start_addr = @intToPtr(*T, self.next);
    var end_addr = @ptrToInt(start_addr) + size;

    if (end_addr > self.heap_end) {
        return AllocationError.OutOfMemory;
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
