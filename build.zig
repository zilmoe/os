const std = @import("std");

pub fn build(b: *std.Build) anyerror!void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    } });

    const kernel = b.addExecutable(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kinit.zig"),
            .target = target,
            .optimize = optimize,
            .code_model = .medium,
        }),
        .name = "kernel",
    });

    kernel.setLinkerScript(b.path("src/lds/linker.lds"));

    kernel.root_module.addCSourceFiles(.{
        .files = &.{"src/asm/boot.S"},
        .flags = &.{ "-x", "assembler-with-cpp" },
    });

    b.installArtifact(kernel);

    const qemu = switch (target.result.cpu.arch) {
        .riscv64 => "qemu-system-riscv64",
        .riscv32 => "qemu-system-riscv32",
        else => unreachable,
    };

    const qemu_cpu = switch (target.result.cpu.arch) {
        .riscv64 => "rv64",
        .riscv32 => "rv32",
        else => unreachable,
    };

    const qemu_cmd = b.addSystemCommand(&.{
        qemu,                 "-machine",
        "virt",               "-bios",
        "none",               "-kernel",
        "zig-out/bin/kernel", "-m",
        "126M",               "-cpu",
        qemu_cpu,             "-smp",
        "4",                  "-nographic",
        "-serial",            "mon:stdio",
    });

    const qemu_debug_cmd = b.addSystemCommand(&.{
        qemu,                 "-machine",
        "virt",               "-bios",
        "none",               "-kernel",
        "zig-out/bin/kernel", "-m",
        "126M",               "-cpu",
        qemu_cpu,             "-smp",
        "4",                  "-nographic",
        "-serial",            "mon:stdio",
        "-s",                 "-S",
    });

    qemu_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| qemu_cmd.addArgs(args);
    const run_step = b.step("run", "Start the kernel in qemu");
    run_step.dependOn(&qemu_cmd.step);

    qemu_debug_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| qemu_debug_cmd.addArgs(args);
    const run_debug_step = b.step("debug", "Start the kernel in qemu debug");
    run_debug_step.dependOn(&qemu_debug_cmd.step);
}
