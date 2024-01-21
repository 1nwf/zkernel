const std = @import("std");
const process = @import("process.zig");
const Thread = process.Thread;
const arch = @import("arch");
const Deque = @import("../utils/deque.zig").Deque;

const RunQueue = Deque(*Thread, 14);

run_queue: RunQueue,
active_thread: ?*Thread = null,
var self: @This() = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    self = .{
        .run_queue = try RunQueue.init(allocator),
    };
}

pub fn schedule_thread(thread: *Thread) !void {
    try self.run_queue.pushBack(thread);
}

pub fn setActiveThread(ctx: arch.thread.Context, th: ?*Thread) !void {
    if (self.active_thread) |curr_thread| {
        curr_thread.context = ctx;
        try schedule_thread(curr_thread);
    }
    self.active_thread = th;
    if (th) |thread| {
        thread.process.page_dir.load();
    }
}

pub fn run_next(ctx: arch.thread.Context) ?*arch.thread.Context {
    if (self.run_queue.isEmpty()) return null;
    if (self.active_thread) |th| {
        th.context = ctx;
        schedule_thread(th) catch {};
    }
    const next = self.run_queue.popFront() orelse return null;
    self.active_thread = next;
    next.process.page_dir.load();
    return &self.active_thread.?.context;
}

pub fn exit_active_thread(cb: *const fn (usize) void) void {
    if (self.active_thread) |th| {
        th.process.deinit_thread(th, cb);
    }
    self.active_thread = null;
}

pub fn takeCurrentThread() ?*Thread {
    const thread = self.active_thread;
    self.active_thread = null;
    return thread;
}
