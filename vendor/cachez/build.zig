const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cache_module = b.addModule("cache", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/cache.zig"),
    });

    const lib_test = b.addTest(.{
        .root_module = cache_module,
        .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
    });
    const run_test = b.addRunArtifact(lib_test);
    run_test.has_side_effects = true;

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
