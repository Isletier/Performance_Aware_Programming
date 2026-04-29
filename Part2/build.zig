const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const json_mod = b.addModule("Part2", .{
        .root_source_file = b.path("json/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const json_test = b.addTest(.{
        .name = "json-test",
        .root_module = json_mod,
        .use_llvm = true,
    });
    const run_test = b.addRunArtifact(json_test);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_test.step);

    const install_test = b.addInstallArtifact(json_test, .{});
    const test_install_step = b.step("test-install", "Install test binary for gdb");
    test_install_step.dependOn(&install_test.step);

    const json_mod_debug = b.addModule("Part2-debug", .{
        .root_source_file = b.path("json/root.zig"),
        .target = target,
        .optimize = .Debug,
    });
    const json_test_debug = b.addTest(.{
        .name = "json-test-debug",
        .root_module = json_mod_debug,
        .use_llvm = true,
    });
    json_test_debug.root_module.strip = false;
    json_test_debug.root_module.omit_frame_pointer = false;
    const install_test_debug = b.addInstallArtifact(json_test_debug, .{});
    const test_debug_step = b.step("test-debug", "Build unoptimized test binary with full debug info");
    test_debug_step.dependOn(&install_test_debug.step);

    const HaverstineGeneratorExe = b.addExecutable(.{
        .name = "haverstine_gen",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("gen/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(HaverstineGeneratorExe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(HaverstineGeneratorExe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
