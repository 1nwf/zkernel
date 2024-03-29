var FixedAllocator = @import("allocator.zig").fixed_alloc.allocator();

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

pub const PAGE_SIZE = 4096;
const PTEntries = 1024;
const PDEntries = 1024;

pub const PageTableEntry = packed struct {
    present: bool = false,
    rw: u1 = 1, // read/write
    us: u1 = 0, // user/supervisor (1 = user mode (can't r/w kernel pages))
    _: u2 = 0, // reserved by intel
    accessed: u1 = 0,
    dirty: u1 = 0, // dirty (1 = page has been written to)
    rsvd: u2 = 0, // reserved
    avail: u3 = 0, // (avail) ignored
    address: u20 = 0,
    const Self = @This();
    pub fn init(frame: usize) Self {
        return .{ .present = true, .address = @truncate(frame >> 12) };
    }
    pub fn setAddr(self: *Self, addr: usize) *Self {
        self.address = @truncate(addr >> 12);
        return self;
    }
};

const PageTable = struct {
    entries: [PTEntries]PageTableEntry = [_]PageTableEntry{.{}} ** PTEntries,

    fn init(self: *@This()) void {
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
    present: bool = false,
    rw: u1 = 1, // read/write
    us: u1 = 0, // user/supervisor
    wt: u1 = 0, // write through. 1 = disabled
    cache: u1 = 0, // cache disabled
    accessed: u1 = 0,
    _: u1 = 0, // reserved by intel
    ps: u1 = 0, // page size (1 = 4 mib, 0 = 4 kib)
    g: u1 = 0, // global
    avail: u3 = 0, // (avail) ignored
    address: u20 = 0,
    const Self = @This();

    fn setPresent(self: *Self) void {
        self.present = true;
    }
    pub fn setAddr(self: *Self, addr: usize) void {
        self.address = @truncate(addr >> 12);
    }

    pub fn getPageTable(self: *Self) ?*PageTable {
        if (self.address == 0) {
            return null;
        }

        const addr: u32 = @as(u32, self.address) << 12;
        return @ptrFromInt(addr);
    }
};

pub const PageDirectory = extern struct {
    dirs: [PDEntries]PageDirEntry,

    const Self = @This();

    // NOTE: must be page aligned
    pub fn init() Self {
        return .{
            .dirs = [_]PageDirEntry{PageDirEntry{}} ** PDEntries,
        };
    }

    pub inline fn findDir(self: *Self, addr: usize) *PageDirEntry {
        return &self.dirs[dirIndex(addr)];
    }

    pub fn getDirPageTable(self: *Self, virt_addr: usize) ?*PageTable {
        const dir = self.findDir(virt_addr);
        return dir.getPageTable();
    }

    pub fn createDirPageTable(self: *Self, virt_addr: usize) *PageTable {
        var dir_idx = dirIndex(virt_addr);
        var page_table = &(FixedAllocator.alignedAlloc(PageTable, PAGE_SIZE, 1) catch @panic("unable to alloc page table"))[0];
        page_table.init();
        self.dirs[dir_idx].setAddr(@intFromPtr(page_table));
        return page_table;
    }

    pub fn mapPage(self: *Self, virt_addr: usize, phys_addr: usize) void {
        self.findDir(virt_addr).setPresent();

        var page_table: *PageTable = blk: {
            var table = self.getDirPageTable(virt_addr);
            if (table) |t| {
                break :blk t;
            }
            break :blk self.createDirPageTable(virt_addr);
        };

        var pt_entry = page_table.findEntry(virt_addr);
        pt_entry.* = PageTableEntry.init(phys_addr);
    }

    pub fn mapUserPage(self: *Self, virt_addr: usize, phys_addr: usize) void {
        var dir = self.findDir(virt_addr);
        dir.setPresent();
        dir.us = 1;

        var page_table: *PageTable = blk: {
            var table = self.getDirPageTable(virt_addr);
            if (table) |t| {
                break :blk t;
            }
            break :blk self.createDirPageTable(virt_addr);
        };

        var pt_entry = page_table.findEntry(virt_addr);
        pt_entry.* = PageTableEntry.init(phys_addr);
        pt_entry.*.us = 1;
    }

    /// maps  contiguous blocks of memory
    /// args must be page aligned
    pub fn mapRegions(self: *Self, phys_addr: usize, virt_addr: usize, region_size: usize) void {
        std.debug.assert(isPageAligned(phys_addr));
        std.debug.assert(isPageAligned(virt_addr));
        var start: usize = 0;
        while (start < region_size) : (start += PAGE_SIZE) {
            self.mapPage(virt_addr + start, phys_addr + start);
        }
    }

    pub fn mapUserRegions(self: *Self, phys_addr: usize, virt_addr: usize, region_size: usize) void {
        std.debug.assert(isPageAligned(phys_addr));
        std.debug.assert(isPageAligned(virt_addr));
        var start: usize = 0;
        while (start < region_size) : (start += PAGE_SIZE) {
            self.mapUserPage(virt_addr + start, phys_addr + start);
        }
    }

    pub fn unmapPage(self: *Self, addr: usize) ?usize {
        var page_table = self.getDirPageTable(addr) orelse return null;
        var table_entry = page_table.findEntry(addr);
        if (!table_entry.present) return null;
        table_entry.present = false;
        return @as(usize, table_entry.address << 12);
    }

    pub fn load(self: *Self) void {
        asm volatile (
            \\ mov %[addr], %%cr3
            :
            : [addr] "{eax}" (@intFromPtr(self)),
        );
    }

    pub fn deinit(self: *Self, cb: *const fn (usize) void) void {
        // TODO: improve performance by tracking allocations
        for (&self.dirs) |*dir| {
            const page_table = dir.getPageTable() orelse continue;
            for (&page_table.entries) |*pte| {
                if (pte.present and pte.us == 1) {
                    cb(@as(u32, pte.address) << 12);
                }
            }
            FixedAllocator.destroy(page_table);
        }
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
        \\ invlpg (%[addr])
        :
        : [addr] "r" (addr),
    );
}

pub fn isPageAligned(addr: usize) bool {
    return addr & 0xFFF == 0;
}
