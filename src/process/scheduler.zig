const std = @import("std");
const process = @import("process.zig");
const Thread = process.Thread;
const arch = @import("arch");
const Deque = @import("../utils/deque.zig").Deque;

const RunningQueue = Deque(Thread, 14);

running_queue: RunningQueue,
active_thread: ?Thread = null,
var self: @This() = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    self = .{
        .running_queue = try RunningQueue.init(allocator),
    };
}

pub fn schedule_thread(thread: Thread) !void {
    try self.running_queue.pushBack(thread);
}

pub fn run_next() ?*arch.thread.Context {
    if (self.active_thread) |th| {
        schedule_thread(th) catch {};
    }
    const next = self.running_queue.popFront() orelse return null;
    self.active_thread = next;
    return &self.active_thread.?.context;
}

pub fn exit_active_thread(cb: *const fn (usize) void) void {
    if (self.active_thread) |th| {
        th.process.deinit(cb);
    }
    self.active_thread = null;
}
