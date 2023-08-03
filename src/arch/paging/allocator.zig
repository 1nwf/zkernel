const std = @import("std");

var buffer: [1024 * 1024]u8 = undefined;
pub var fixed_alloc = std.heap.FixedBufferAllocator.init(&buffer);
