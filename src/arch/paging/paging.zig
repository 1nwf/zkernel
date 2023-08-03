pub const FrameAllocator = @import("bump_alloc.zig").BumpAllocator;
var FixedAllocator = @import("allocator.zig").fixed_alloc.allocator();
const writeln = @import("../serial.zig").writeln;

extern const kernel_start: usize;
extern const kernel_end: usize;

const std = @import("std");

pub fn enable_paging() void {
    asm volatile (
        \\ mov %%cr0, %%eax
        \\ mov $0x1, %%edx
        \\ shl $31, %%edx
        \\ or %%edx, %%eax
        \\ mov %%eax, %%cr0
    );
}

pub fn isEnabled() bool {
    const cr0 = asm volatile (
        \\ mov %%cr0, %[cr0]
        : [cr0] "={eax}" (-> u32),
    );

    return (cr0 >> 31) == 1;
}

// NOTE: address that caused page fault is stored in the `cr2` register
pub fn pageFaultHandler() void {}

// NOTE: in protected mode, two level paging is used
// an address is first translated from a logical --> linear via segmentation
// then it is translated from linear --> physical via paging
// the active page directory is stored in the cr3 register
// page directory consists of entries that point to page tables
// page tables consist of entries that point to 4 Kib phsyical frames
// both page directory and table consist of 1024 4-byte entries
// an address consists of 3 parts:
// the first 10 bits is the index of page directory entry
// the second 10 bits is the index page table entry
// the last 12 bits is the page offset. it is added to the base address of the
// physical frame that is pointed to by the corresponding page table entry.
// Page Frame addresses only need 20 bits since they are 4kib aligned. the lower 12 bits are zeroed out.

const PAGE_SIZE = 4096;
const PTEntries = 1024;
const PDEntries = 1024;

pub const PageTableEntry = packed struct {
    present: u1 = 0,
    rw: u1 = 1, // read/write
    us: u1 = 1, // user/supervisor (1 = user mode (can't r/w kernel pages))
    _: u2 = 0, // reserved by intel
    accessed: u1 = 0,
    dirty: u1 = 0, // dirty (1 = page has been written to)
    rsvd: u2 = 0, // reserved
    avail: u3 = 0, // (avail) ignored
    address: u20 = 0,
    pub fn init(frame: usize) @This() {
        return .{ .present = 1, .address = @truncate(frame >> 12) };
    }
    pub fn setAddr(self: *@This(), addr: usize) *@This() {
        self.address = @truncate(addr >> 12);
        return self;
    }
};

const PageTable = struct {
    entries: [PTEntries]PageTableEntry = [_]PageTableEntry{.{}} ** PTEntries,
    pub fn init() PageTable {
        return .{};
    }

    fn setDefault(self: *@This()) void {
        self.entries = [_]PageTableEntry{.{}} ** PTEntries;
    }

    fn setEntry(self: @This(), idx: usize, entry: PageTableEntry) void {
        self.entries[idx] = entry;
    }

    inline fn findEntry(self: *@This(), addr: usize) *PageTableEntry {
        return &self.entries[tableIndex(addr)];
    }
};

pub const PageDirEntry = packed struct {
    present: u1 = 0,
    rw: u1 = 1, // read/write
    us: u1 = 1, // user/supervisor
    wt: u1 = 0, // write through. 1 = disabled
    cache: u1 = 0, // cache disabled
    accessed: u1 = 0,
    _: u1 = 0, // reserved by intel
    ps: u1 = 0, // page size (1 = 4 mib, 0 = 4 kib)
    g: u1 = 0, // global
    avail: u3 = 0, // (avail) ignored
    address: u20 = 0,
    pub fn init(pt_addr: u20) @This() {
        return .{ .present = 1, .address = pt_addr };
    }

    fn setPresent(self: *@This()) *@This() {
        self.present = 1;
        return self;
    }
    pub fn setAddr(self: *@This(), addr: u32) void {
        self.address = @truncate(addr >> 12);
    }
};

pub const PageDirectory = struct {
    dirs: [PDEntries]PageDirEntry,
    pageTables: [PDEntries]?*PageTable,
    pub fn init() align(PAGE_SIZE) @This() {
        return .{
            .dirs = [_]PageDirEntry{PageDirEntry{}} ** PDEntries,
            .pageTables = [_]?*PageTable{null} ** PDEntries,
        };
    }

    // identity maps the kernel for now
    pub fn identityMap(self: *@This()) void {
        var start: usize = 0;
        const end = @intFromPtr(&kernel_end) + 1;
        while (start < end) : (start += PAGE_SIZE) {
            self.mapPage(start, start);
        }
    }

    inline fn findDir(self: *@This(), addr: usize) *PageDirEntry {
        return &self.dirs[dirIndex(addr)];
    }

    pub fn getDirPageTable(self: *@This(), virt_addr: usize) ?*PageTable {
        return self.pageTables[dirIndex(virt_addr)];
    }

    pub fn createDirPageTable(self: *@This(), virt_addr: usize) *PageTable {
        var dir_idx = dirIndex(virt_addr);
        var page_table = &(FixedAllocator.alignedAlloc(PageTable, PAGE_SIZE, 1) catch @panic("unable to alloc page table"))[0];
        page_table.setDefault();
        self.pageTables[dir_idx] = page_table;
        return page_table;
    }

    fn mapPage(self: *@This(), virt_addr: usize, phys_addr: usize) void {
        var dir = self.findDir(virt_addr).setPresent();

        var page_table: *PageTable = blk: {
            var table = self.getDirPageTable(virt_addr);
            if (table) |t| {
                break :blk t;
            }
            break :blk self.createDirPageTable(virt_addr);
        };

        var pt_entry = page_table.findEntry(virt_addr);
        pt_entry.* = PageTableEntry.init(phys_addr);

        dir.setAddr(@intFromPtr(page_table));
    }

    pub fn load(self: *@This()) void {
        asm volatile (
            \\ mov %[addr], %%cr3
            :
            : [addr] "{eax}" (@intFromPtr(self)),
        );
    }
};

pub inline fn dirIndex(addr: usize) u10 {
    return @truncate((addr >> 22) & 0x3FF);
}
pub inline fn tableIndex(addr: usize) u10 {
    return @truncate((addr >> 12) & 0x3FF);
}

/// invalidates tlb cache entry for the page associated with the given address
pub fn flushTlbEntry(addr: usize) void {
    asm volatile (
        \\ invlpg (%[addr]),
        :
        : [addr] "r" (addr),
    );
}
