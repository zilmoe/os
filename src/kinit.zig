const std = @import("std");
const uart = @import("uart/uart.zig");
const kmain = @import("kmain.zig");
const alloc = @import("alloc/kernel_alloc.zig");
const vm = @import("vm/vm.zig");
const trap = @import("trap/trap.zig");

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

fn enable_s_mode() noreturn {
    const mstatus: u64 = (0x0b01 << 11) | (1 << 7) | (1 << 3);
    asm volatile ("csrw mstatus, %[v]"
        :
        : [v] "r" (mstatus),
    );
    asm volatile ("csrw mepc, %[v]"
        :
        : [v] "r" (@intFromPtr(&kmain.kmain)),
    );

    // PMP set up
    asm volatile ("csrw pmpaddr0, %[v]"
        :
        : [v] "r" (@as(u64, 0x3FFFFFFFFFFFFF)),
    );

    // trap handler stub (TODO always point to stub)
    asm volatile ("csrw mtvec, %[v]"
        :
        : [v] "r" (@intFromPtr(&trap.trap_vector)),
    );

    asm volatile ("csrw pmpcfg0, %[v]"
        :
        : [v] "r" (@as(u64, 0xF)),
    );

    asm volatile ("csrc mstatus, %[v]"
        :
        : [v] "r" (@as(u64, 1 << 20)),
    );

    // ensure satp is cleared
    asm volatile ("csrw satp, zero");
    asm volatile ("mret");
    unreachable;
}

// This is the kernel's entrypoint which will be invoked by the booting
// CPU (aka hart) after the boot code has executed.
export fn kinit() callconv(.c) void {
    uart.init();
    _ = alloc.kminit();
    enable_s_mode();
}
