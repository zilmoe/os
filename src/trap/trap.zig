const mn = @import("../kinit.zig");

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

pub extern fn trap_vector() void;

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
            1 => mn.println("Supervisor software interrupt (hart {})", .{hart}),
            3 => mn.println("Machine software interrupt (hart {})", .{hart}),
            5 => mn.println("Supervisor timer interrupt (hart {})", .{hart}),
            7 => mn.println("Machine timer interrupt (hart {})", .{hart}),
            9 => mn.println("Supervisor external interrupt (hart {})", .{hart}),
            11 => mn.println("Machine external interrupt (hart {})", .{hart}),
            13 => mn.println("Counter overflow interrupt (hart {})", .{hart}),
            else => mn.println("Unknown interrupt {} (hart {})", .{ cause_num, hart }),
        }
    } else {
        switch (cause_num) {
            0 => mn.println("Instruction address misaligned: {x}", .{tval}),
            1 => mn.println("Instruction access fault: {x}", .{tval}),
            2 => mn.println("Illegal instruction: {x} at {x}", .{ tval, epc }),
            3 => mn.println("Breakpoint at {x}", .{epc}),
            4 => mn.println("Load address misaligned: {x}", .{tval}),
            5 => mn.println("Load access fault: {x}", .{tval}),
            6 => mn.println("Store/AMO address misaligned: {x}", .{tval}),
            7 => mn.println("Store/AMO access fault: {x}", .{tval}),
            8 => mn.println("Ecall from U-mode at {x}", .{epc}),
            9 => mn.println("Ecall from S-mode at {x}", .{epc}),
            10 => mn.println("Ecall from VS-mode at {x}", .{epc}),
            11 => mn.println("Ecall from M-mode at {x}", .{epc}),
            12 => mn.println("Instruction page fault: {x}", .{tval}),
            13 => mn.println("Load page fault: {x}", .{tval}),
            15 => mn.println("Store/AMO page fault: {x}", .{tval}),
            16 => mn.println("Double trap at {x}", .{epc}),
            18 => mn.println("Software check at {x} (tval {x})", .{ epc, tval }),
            19 => mn.println("Hardware error at {x}", .{epc}),
            20 => mn.println("Instruction guest-page fault: {x}", .{tval}),
            21 => mn.println("Load guest-page fault: {x}", .{tval}),
            22 => mn.println("Virtual instruction: {x} at {x}", .{ tval, epc }),
            23 => mn.println("Store/AMO guest-page fault: {x}", .{tval}),
            else => mn.println("Unknown exception {} at {x} (tval {x})", .{ cause_num, epc, tval }),
        }
    }
    while (true) {}
    return ret_pc;
}
