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
    header: u64,
    mem: [4096]u8 align(4096) = undefined,
};

const linked_list = struct {
    next_node: ?*linked_list,
};

var free_list: ?*linked_list = null;

pub fn kminit() bool {
    mn.println("KERNEL END: {}", .{&_bss_end});
    mn.println("HEAP START: {}", .{&_heap_start});
    mn.println("MEMORY END: {}", .{&_memory_end});
    mn.println("STACK: {}", .{&_stack});

    // calculate number of chunks
    const chunk_num = (mem_map.RAM_END() - mem_map.RAM_START()) / (4096 + 8);

    free_list = @ptrFromInt(mem_map.RAM_START());

    var curr: ?*linked_list = free_list;
    // this cast causes chunk to be NULL
    const chunks: [*]chunk = @ptrFromInt(mem_map.RAM_START());

    for (1..chunk_num) |i| {
        if (curr) |ptr| {
            if (i + 1 == chunk_num) {
                ptr.next_node = null;
            } else {
                ptr.next_node = @ptrCast(&chunks[i + 1]);
            }
            curr = ptr.next_node;
        } else {
            return false;
        }
    }

    mn.println("number of chunks: {}", .{chunk_num});
    mn.println("ram allocator initialized", .{});
    return true;
}

pub fn kalloc() ?*linked_list {
    // return from free list if possible
    if (free_list) |free_chunk| {
        const curr: ?*linked_list = free_chunk;
        free_list = free_chunk.next_node;
        return curr;
    } else {
        return null;
    }
}

pub fn kfree(free_chunk: u64) void {
    const new_free_chunk: ?*linked_list = @ptrFromInt(free_chunk);
    new_free_chunk.next_node = free_list;
    free_list = new_free_chunk;
}
