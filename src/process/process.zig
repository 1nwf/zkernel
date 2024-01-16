const std = @import("std");

const arch = @import("arch");
const Context = arch.thread.Context;
const gdt = arch.gdt;
const paging = arch.paging;

const mem = @import("../mem/mem.zig");
const PhysFrameAllocator = mem.pmm;

const THREAD_STACK_SIZE = arch.paging.PAGE_SIZE;

var COUNTER: struct {
    val: usize = 0,
    fn next(self: *@This()) usize {
        return @atomicRmw(usize, &self.val, .Add, 1, .Acquire);
    }
} = .{};

const Process = @This();
page_dir: paging.PageDirectory align(paging.PAGE_SIZE),
phys_frame_allocator: *PhysFrameAllocator,

pub fn init(phys_frame_allocator: *PhysFrameAllocator) Process {
    return .{
        .page_dir = paging.PageDirectory.init(),
        .phys_frame_allocator = phys_frame_allocator,
    };
}

pub fn deinit(self: *Process, cb: *const fn (usize) void) void {
    self.page_dir.deinit(cb);
}

pub fn mapPages(
    self: *Process,
    virt_addr: usize,
    size: usize,
) !void {
    var start: usize = 0;
    while (start < size) : (start += paging.PAGE_SIZE) {
        const phys_addr = try self.phys_frame_allocator.alloc();
        self.page_dir.mapUserPage(virt_addr + start, phys_addr);
    }
}

pub fn new_thread(self: *Process, entrypoint: usize) !Thread {
    const stack_phys_start = try self.phys_frame_allocator.alloc();
    const stack_start = 0;
    const stack_end = stack_start + arch.paging.PAGE_SIZE;
    self.page_dir.mapUserPage(stack_start, stack_phys_start);
    return .{
        .tid = COUNTER.next(),
        .process = self,
        .stack_end = stack_end,
        .stack_size = THREAD_STACK_SIZE,
        .context = Context.init_user_context(entrypoint, stack_end),
    };
}

pub const Thread = struct {
    tid: usize,
    process: *Process,
    stack_end: usize,
    stack_size: usize,
    context: Context,
};
