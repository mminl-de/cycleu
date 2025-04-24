const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "cycleu",
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();

    b.installArtifact(lib);

    const lib_tests = b.addTest(.{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_tests.linkLibC();
    lib_tests.linkSystemLibrary("curl");

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);

    const AllocatorType = enum { c, testing };
    const allocator_choice = b.option(AllocatorType, "allocator", "Choose the testing allocator");

    const test_options = b.addOptions();
    test_options.addOption(AllocatorType, "allocator", allocator_choice orelse .testing);
    lib_tests.root_module.addOptions("tests", test_options);
}
