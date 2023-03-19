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
    var cr0: u32 = 0;
    asm volatile (
        \\ mov %%cr0, %[cr0]
        : [cr0] "={eax}" (cr0),
    );

    return (cr0 >> 31) == 1;
}

// NOTE: address that caused page fault is stored in the `cr2` register

fn pageFaultHandler() void {}

// NOTE: in protected mode, two level paging is used
// an address is first translated from a logical --> linear via segmentation
// then it is translated from linear --> physical via paging
// the active page directory is stored in the cr3
// page directory consists of entries that point to page tables
// page tables consist of entries that point to 4 Kib phsyical frames
// both page directory and table consist of 1024 4-byte entries
// an address consists of 3 parts:
// the first 10 bits is the index of page directory entry
// the second 10 bits is the index page table entry
// the last 12 bits is the page offset. it is added to the base address of the physical frame that is pointed to by the corresponding page table entry

const PAGE_SIZE = 4096;
const PTEntries = 1024;
const PDEntries = 1024;

/// Page Table Entry
pub const PTE = packed struct {
    present: u1,
    // read/write
    rw: u1,
    // user/supervisor
    us: u1,
    // write through
    pwt: u1,
    // cache disabled
    pcd: u1,
    // accessed
    accessed: u1,
    // dirty
    dirty: u1,
    // page attr. table
    pat: u1,
    // if translation is global
    global: u1,
    // ignored
    _: u3,

    address: u20,
};

/// Page Directory Entry
const PDE = packed struct {
    present: u1,
    // read/write
    // if 0, writes are not allowed
    rw: u1,
    // user/supervisor
    // if 0, user mode access are note allowed
    us: u1,
    // Page-level write-through. if set, write-through caching is enabled. else, write back caching is used
    pwt: u1,
    // page level cache disable
    pcd: u1,
    accessed: u1,
    // ignored
    _: u1,
    // page size
    ps: u1,
    _: u3,
    pt_addr: u20,
};
