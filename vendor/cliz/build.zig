const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Optional: expose module if reused
    const mod = b.addModule("zli", .{
        .root_source_file = b.path("src/zli.zig"),
        .single_threaded = false,
        .target = target,
        .optimize = optimize,
    });

    // Test runner
    const lib_test = b.addTest(.{
        .root_module = mod,
    });

    const run_test = b.addRunArtifact(lib_test);
    run_test.has_side_effects = true;

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);

    const docs_step = b.step("docs", "Build the zli library docs");
    const docs_obj = b.addObject(.{
        .name = "zli",
        .root_module = mod,
    });
    const docs = docs_obj.getEmittedDocs();
    docs_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = docs,
        .install_dir = .prefix,
        .install_subdir = "docs",
    }).step);
}
