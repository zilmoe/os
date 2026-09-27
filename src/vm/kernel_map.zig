const std = @import("std");
extern const _bss_start: u64;
extern const _stack: u64;

// UART0 address to write at
pub const UART0 = 0x10000000;
pub const UART_IRQ = 10;

pub const VIRTIO0 = 0x10001000;
pub const VIRTIO0_IRQ = 1;

// Page size
pub const PAGE_SIZE = 4096;

// kernel base
pub const KERNBASE = 0x80000000;
pub fn RAM_START() u64 {
    return std.mem.alignForward(usize, @intFromPtr(&_bss_start), PAGE_SIZE);
}
pub fn RAM_END() u64 {
    return @intFromPtr(&_stack);
}
pub fn PAGE_NUM() u64 {
    return (RAM_END() - RAM_START()) / PAGE_SIZE;
}
