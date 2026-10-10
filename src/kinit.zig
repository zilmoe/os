const std = @import("std");
const uart = @import("uart/uart.zig");
const kmain = @import("kmain.zig");
const alloc = @import("alloc/kernel_alloc.zig");
const vm = @import("vm/vm.zig");

comptime {
    asm (
        \\.section .text
        \\.global trap_vector
        \\.balign 4
        \\trap_vector:
        \\    addi sp, sp, -256
        \\    sd x1,    8(sp)
        \\    sd x3,   24(sp)
        \\    sd x4,   32(sp)
        \\    sd x5,   40(sp)
        \\    sd x6,   48(sp)
        \\    sd x7,   56(sp)
        \\    sd x8,   64(sp)
        \\    sd x9,   72(sp)
        \\    sd x10,  80(sp)
        \\    sd x11,  88(sp)
        \\    sd x12,  96(sp)
        \\    sd x13, 104(sp)
        \\    sd x14, 112(sp)
        \\    sd x15, 120(sp)
        \\    sd x16, 128(sp)
        \\    sd x17, 136(sp)
        \\    sd x18, 144(sp)
        \\    sd x19, 152(sp)
        \\    sd x20, 160(sp)
        \\    sd x21, 168(sp)
        \\    sd x22, 176(sp)
        \\    sd x23, 184(sp)
        \\    sd x24, 192(sp)
        \\    sd x25, 200(sp)
        \\    sd x26, 208(sp)
        \\    sd x27, 216(sp)
        \\    sd x28, 224(sp)
        \\    sd x29, 232(sp)
        \\    sd x30, 240(sp)
        \\    sd x31, 248(sp)
        \\
        \\    csrr a0, mepc
        \\    csrr a1, mtval
        \\    csrr a2, mcause
        \\    csrr a3, mhartid
        \\    csrr a4, mstatus
        \\    call trap
        \\    csrw mepc, a0
        \\
        \\    ld x1,    8(sp)
        \\    ld x3,   24(sp)
        \\    ld x4,   32(sp)
        \\    ld x5,   40(sp)
        \\    ld x6,   48(sp)
        \\    ld x7,   56(sp)
        \\    ld x8,   64(sp)
        \\    ld x9,   72(sp)
        \\    ld x10,  80(sp)
        \\    ld x11,  88(sp)
        \\    ld x12,  96(sp)
        \\    ld x13, 104(sp)
        \\    ld x14, 112(sp)
        \\    ld x15, 120(sp)
        \\    ld x16, 128(sp)
        \\    ld x17, 136(sp)
        \\    ld x18, 144(sp)
        \\    ld x19, 152(sp)
        \\    ld x20, 160(sp)
        \\    ld x21, 168(sp)
        \\    ld x22, 176(sp)
        \\    ld x23, 184(sp)
        \\    ld x24, 192(sp)
        \\    ld x25, 200(sp)
        \\    ld x26, 208(sp)
        \\    ld x27, 216(sp)
        \\    ld x28, 224(sp)
        \\    ld x29, 232(sp)
        \\    ld x30, 240(sp)
        \\    ld x31, 248(sp)
        \\    addi sp, sp, 256
        \\    mret
    );
}

extern fn trap_vector() void;

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
    // silence warnings
    _ = status;
    // async vs sync trap
    const cause_num = cause & 0xfff;
    const ret_pc = epc;
    const is_async: u64 = ((cause >> 63) & 1);

    if (is_async == 1) {
        switch (cause_num) {
            1 => println("Supervisor software interrupt (hart {})", .{hart}),
            3 => println("Machine software interrupt (hart {})", .{hart}),
            5 => println("Supervisor timer interrupt (hart {})", .{hart}),
            7 => println("Machine timer interrupt (hart {})", .{hart}),
            9 => println("Supervisor external interrupt (hart {})", .{hart}),
            11 => println("Machine external interrupt (hart {})", .{hart}),
            13 => println("Counter overflow interrupt (hart {})", .{hart}),
            else => println("Unknown interrupt {} (hart {})", .{ cause_num, hart }),
        }
    } else {
        switch (cause_num) {
            0 => println("Instruction address misaligned: {x}", .{tval}),
            1 => println("Instruction access fault: {x}", .{tval}),
            2 => println("Illegal instruction: {x} at {x}", .{ tval, epc }),
            3 => println("Breakpoint at {x}", .{epc}),
            4 => println("Load address misaligned: {x}", .{tval}),
            5 => println("Load access fault: {x}", .{tval}),
            6 => println("Store/AMO address misaligned: {x}", .{tval}),
            7 => println("Store/AMO access fault: {x}", .{tval}),
            8 => println("Ecall from U-mode at {x}", .{epc}),
            9 => println("Ecall from S-mode at {x}", .{epc}),
            10 => println("Ecall from VS-mode at {x}", .{epc}),
            11 => println("Ecall from M-mode at {x}", .{epc}),
            12 => println("Instruction page fault: {x}", .{tval}),
            13 => println("Load page fault: {x}", .{tval}),
            15 => println("Store/AMO page fault: {x}", .{tval}),
            16 => println("Double trap at {x}", .{epc}),
            18 => println("Software check at {x} (tval {x})", .{ epc, tval }),
            19 => println("Hardware error at {x}", .{epc}),
            20 => println("Instruction guest-page fault: {x}", .{tval}),
            21 => println("Load guest-page fault: {x}", .{tval}),
            22 => println("Virtual instruction: {x} at {x}", .{ tval, epc }),
            23 => println("Store/AMO guest-page fault: {x}", .{tval}),
            else => println("Unknown exception {} at {x} (tval {x})", .{ cause_num, epc, tval }),
        }
    }
    while (true) {}
    return ret_pc;
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
        : [v] "r" (@intFromPtr(&trap_vector)),
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
