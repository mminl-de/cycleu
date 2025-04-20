const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "libcycleu",
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);
}
