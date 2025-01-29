const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add the CLI executable
    const exe = b.addExecutable(.{
        .name = "termynus",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Add WASM library
    const wasm = b.addSharedLibrary(.{
        .name = "termynus",
        .root_source_file = .{ .path = "src/wasm.zig" },
        .target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
        .optimize = optimize,
    });

    // Configure WASM settings
    // wasm.import_memory = true;
    // wasm.initial_memory = 65536;
    // wasm.max_memory = 65536;
    // wasm.stack_size = 32768;

    // Export all functions
    wasm.export_symbol_names = &[_][]const u8{
        "tokenize",
        "shuntingYard",
        "parseToTree",
        "evaluate",
        "getStringLen",
    };

    // Install WASM to lib directory
    b.installArtifact(wasm);

    // Add a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the term evaluator");
    run_step.dependOn(&run_cmd.step);
}
