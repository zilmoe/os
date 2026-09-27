// this is the file that sets up a page table
// for the kernel or a user process
// the kernel is direct mapped
// I have no clue what processes are (have to study more)

const mem_map = @import("./kernel_map.zig");

// creates the page table for the kernel
pub fn kptable_make() void {
    var x = 0;
}

// stores a virtual address in a page table
// corresponding to a physical address
fn ptable_store(p_table: u64, v_addr: u64, p_addr: u64) !void {}
