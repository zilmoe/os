// this is the file that sets up a page table
// for the kernel or a user process
// the kernel is direct mapped
// I have no clue what processes are (have to study more)
// https://mit-pdos.github.io/xv6-riscv-book/mem.html

const allocator = @import("../alloc/kernel_alloc.zig");
const mem_map = @import("./kernel_map.zig");
const mn = @import("../kinit.zig");

// might not be the best way to do this
const page_entry = packed struct {
    reserved: u10,
    ppn: u44,
    rsw: u2,
    dirty: u1,
    accessed: u1,
    global: u1,
    user: u1,
    executable: u1,
    writeable: u1,
    readable: u1,
    valid: u1,
};

const page_dir = struct {
    entries: *[512]page_entry,
};

// change these to use Zig's error set type
pub fn kptable_init() void {
    const ptable_addr: u64 = kptable_make();
    // load into satp here
    asm volatile ("csrw satp, a0"
        :
        : [arg1] "{a0}" (ptable_addr),
    );
    mn.println("virtual memory and page table initialized.", .{});
}

// creates the page table for the kernel
fn kptable_make() u64 {
    const page_table: *page_dir = @ptrCast(allocator.kalloc());
    const res: bool = ptable_store(page_table, mem_map.KERNBASE, mem_map.KERNBASE); // do i have to add more addresses? Since the kernel is more than a page in size?
    _ = res;
    _ = ptable_store(page_table, mem_map.UART0, mem_map.UART0);
    _ = ptable_store(page_table, mem_map.VIRTIO0, mem_map.VIRTIO0);

    return @intFromPtr(page_table);
}

// stores a virtual address in a page table
// corresponding to a physical address
fn ptable_store(p_table: *page_dir, v_addr: u64, p_addr: u64) bool {
    const l_zero_offset = (v_addr >> 12) & 0x1FF;
    const l_one_offset = (v_addr >> 21) & 0x1FF;
    const l_two_offset = (v_addr >> 30) & 0x1FF;

    var l_two_entry: page_entry = p_table.entries[l_two_offset];
    var l_one_table: ?*page_dir = null;

    // access the first table
    if (l_two_entry.valid == 1) {
        // this might be fucked add test case
        l_one_table = @ptrFromInt(l_two_entry.ppn);
    } else {
        l_one_table = @ptrCast(allocator.kalloc());
        const ppn_one_table: u44 = @intCast((@intFromPtr(l_one_table) >> 12));
        l_two_entry.valid = 1;
        l_two_entry.ppn = ppn_one_table;
    }

    // l_one_table should now contain either null or the page table 2nd layer
    var l_zero_table: ?*page_dir = null;
    if (l_one_table) |one_table| {
        var l_one_entry: page_entry = one_table.entries[l_one_offset];

        if (l_one_entry.valid == 1) {
            // this might be fucked add test case
            l_zero_table = @ptrFromInt(l_one_entry.ppn);
        } else {
            l_zero_table = @ptrCast(allocator.kalloc());
            const ppn_zero_table: u44 = @intCast((@intFromPtr(l_zero_table) >> 12));
            l_one_entry.valid = 1;
            l_one_entry.ppn = ppn_zero_table;
        }
    } else {
        return false;
    }

    // l_zero_table should now contain either null or the page table 3rd layer
    if (l_zero_table) |zero_table| {
        // time to store the PPN!!!!
        var l_zero_entry: page_entry = zero_table.entries[l_zero_offset];

        const ppn_addr: u44 = @intCast(p_addr >> 12);
        l_zero_entry.valid = 1;
        l_zero_entry.ppn = ppn_addr;
    } else {
        return false;
    }

    return true;
}
