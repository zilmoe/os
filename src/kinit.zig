const std = @import("std");
const uart = @import("uart/uart.zig");
const kmain = @import("kmain.zig");
const alloc = @import("alloc/kernel_alloc.zig");
const vm = @import("vm/vm.zig");

// Here we set up a printf-like writer from the standard library by providing
// a way to output via the UART.
pub fn drainUart(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
    _ = try uartPutStr(w.buffer);
    w.end = 0;
    var bytes_written: usize = 0;
    for (data[0 .. data.len - 1]) |slice| {
        bytes_written += try uartPutStr(slice);
    }
    if (splat == 0 or data.len < 1) return bytes_written;
    const last_data = data[data.len - 1];
    for (0..splat) |_| {
        bytes_written += try uartPutStr(last_data);
    }
    return bytes_written;
}

var uart_writer = std.Io.Writer{
    .buffer = &[_]u8{} ** 1024,
    .end = 0,
    .vtable = &.{ .drain = drainUart },
};

fn uartPutStr(str: []const u8) !usize {
    for (str) |ch| {
        uart.putChar(ch);
    }
    return str.len;
}

pub fn println(comptime fmt: []const u8, args: anytype) void {
    uart_writer.print(fmt ++ "\n", args) catch {};
}

// This the trap/exception entrypoint, this will be invoked any time
// we get an exception (e.g if something in the kernel goes wrong) or
// an interrupt gets delivered.
export fn trap(epc: u64, tval: u64, cause: u64, hart: u64, status: u64) align(4) callconv(.c) u64 {
    // silence the warnings
    _ = tval;
    _ = status;
    // async vs sync trap
    const cause_num = cause & 0xfff;
    const ret_pc = epc;
    const is_async: u64 = ((cause >> 63) & 1);
    if (is_async == 1) {
        switch (cause_num) {
            3 => {
                println("Machine software int! {}", .{hart});
            },
            7 => {
                println("Machine timer!! {}", .{hart});
            },
            11 => {
                println("Machine external int! {}", .{hart});
            },
            else => {
                println("Unhandled int! {}", .{hart});
            },
        }
    } else {
        switch (cause_num) {
            2 => {
                println("Illegal instruction! {}", .{hart});
            },
            8 => {
                println("E-call from User Mode! {}", .{hart});
            },
            else => {
                println("Unhandled: {}!", .{cause_num});
            },
        }
    }
    while (true) {}
    return ret_pc;
}

// This is the kernel's entrypoint which will be invoked by the booting
// CPU (aka hart) after the boot code has executed.
export fn kinit() callconv(.c) void {
    uart.init();
    _ = alloc.kminit();
    vm.kptable_init();
    println("Zig is running on barebones RISC-V (rv{})!", .{@bitSizeOf(usize)});
    const ret_val: u64 = kmain.kmain();
    // do something if the kernel fails...
    _ = ret_val;
}
