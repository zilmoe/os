const mn = @import("./kinit.zig");
const vm = @import("./vm/vm.zig");

// https://www.youtube.com/watch?v=pXwnRqehZV8
pub fn kmain() u64 {
    vm.kptable_init();
    mn.println("Zig is running on barebones RISC-V (rv{})!", .{@bitSizeOf(usize)});
    while (true) {}
}
