// Kernel malloc, manages the kernel memory
// For now, a simple linked list will do.

const std = @import("std");
const mem_map = @import("../vm/kernel_map.zig");
const mn = @import("../kinit.zig");
extern const _bss_end: u64;
extern const _heap_start: u64;
extern const _memory_end: u64;
extern const _stack: u64;

const chunk = struct {
    mem: [4096]u8 align(4096) = undefined,
};

const linked_list = struct {
    next_node: ?*linked_list,
};

pub fn kminit() bool {
    mn.println("KERNEL END: {}", .{mem_map.RAM_START()});
    mn.println("KERNEL END: {}", .{&_bss_end});
    mn.println("MEMORY END: {}", .{&_heap_start});
    mn.println("MEMORY END: {}", .{&_memory_end});
    mn.println("STACK: {}", .{&_stack});

    const head_node: ?*linked_list = @ptrFromInt(mem_map.RAM_START());

    var curr: ?*linked_list = head_node;
    // this cast causes chunk to be NULL
    const chunks: [*]chunk = @ptrFromInt(mem_map.RAM_START());

    for (1..mem_map.PAGE_NUM()) |i| {
        if (curr) |ptr| {
            if (i + 1 == mem_map.PAGE_NUM()) {
                ptr.next_node = null;
            } else {
                ptr.next_node = @ptrCast(&chunks[i + 1]);
            }
            curr = ptr.next_node;
        } else {
            return false;
        }
    }

    mn.println("ram allocator initialized", .{});
    return true;
}
