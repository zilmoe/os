// this is the file that sets up a page table
// for the kernel or a user process
// the kernel is direct mapped
// I have no clue what processes are (have to study more)
// https://mit-pdos.github.io/xv6-riscv-book/mem.html

const allocator = @import("../alloc/kernel_alloc.zig");
const mem_map = @import("./kernel_map.zig");
const mn = @import("../kinit.zig");

extern const _bss_end: u64;

// might not be the best way to do this
const page_entry = packed struct(u64) {
    valid: u1,
    readable: u1,
    writeable: u1,
    executable: u1,
    user: u1,
    global: u1,
    accessed: u1,
    dirty: u1,
    rsw: u2,
    ppn: u44,
    reserved: u10,
};

const page_dir = struct {
    entries: [512]page_entry,
};

// change these to use Zig's error set type
pub fn kptable_init() void {
    const ptable_addr: u64 = kptable_make();
    // load into satp here
    const satp_val: u64 = (8 << 60) | (ptable_addr >> 12);
    asm volatile ("csrw satp, %[val]"
        :
        : [val] "r" (satp_val),
    );
    asm volatile ("sfence.vma" ::: .{ .memory = true });
    mn.println("virtual memory and page table initialized.", .{});
    vm_print(@ptrFromInt(ptable_addr));
}

// creates the page table for the kernel
fn kptable_make() u64 {
    const page_table: ?*page_dir = @ptrCast(allocator.kalloc());
    if (page_table) |chunk| {
        const res: bool = ptable_store(chunk, mem_map.KERNBASE, mem_map.KERNBASE);
        _ = res;
        _ = ptable_addr_store(chunk, mem_map.UART0, mem_map.UART0, 4096);
        _ = ptable_addr_store(chunk, mem_map.VIRTIO0, mem_map.VIRTIO0, 4096);
        // 0x80050080 is the end of the kernel, hardcoded for now.
        _ = ptable_addr_store(chunk, mem_map.KERNBASE, mem_map.KERNBASE, 0x80050080 - mem_map.KERNBASE);
    }
    return @intFromPtr(page_table);
}

fn ptable_addr_store(p_table: *page_dir, v_addr: u64, p_addr: u64, size: u64) bool {
    // check alignement
    if (size % 4096 != 0) {
        return false;
    }
    if (v_addr % 4096 != 0) {
        return false;
    }
    if (p_addr % 4096 != 0) {
        return false;
    }
    for (0..(size % 4096)) |i| {
        const res: bool = ptable_store(p_table, v_addr + (4096 * i), p_addr + (4096 * i));
        if (res == false) {
            return false;
        }
    }

    return true;
}

// stores a virtual address in a page table
// corresponding to a physical address
fn ptable_store(p_table: *page_dir, v_addr: u64, p_addr: u64) bool {
    const l_zero_offset = (v_addr >> 12) & 0x1FF;
    const l_one_offset = (v_addr >> 21) & 0x1FF;
    const l_two_offset = (v_addr >> 30) & 0x1FF;

    const l_two_entry: *page_entry = &p_table.entries[l_two_offset];
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

fn vm_print(page_table: *page_dir) void {
    mn.println("Table One ({x}):", .{@intFromPtr(page_table)});
    var zeros: u32 = 0;
    for (0..512) |i| {
        const entry: page_entry = page_table.entries[i]; // maybe make page_entry nullable?
        if (entry.valid == 1) {
            mn.println("{} zero entries", .{zeros});
            zeros = 0;
            mn.println("Entry {}", .{i});
            mn.println("reserved {}", .{entry.reserved});
            mn.println("ppn {}", .{entry.ppn});
            mn.println("rsw {}", .{entry.rsw});
            mn.println("dirty {}", .{entry.dirty});
            mn.println("accessed {}", .{entry.accessed});
            mn.println("global {}", .{entry.global});
            mn.println("user {}", .{entry.user});
            mn.println("executable {}", .{entry.executable});
            mn.println("writeable {}", .{entry.writeable});
            mn.println("readable {}", .{entry.readable});
            mn.println("valid {}", .{entry.valid});
        } else {
            zeros += 1;
        }
    }
    if (zeros != 0) {
        mn.println("{} zero entries", .{zeros});
    }
}
