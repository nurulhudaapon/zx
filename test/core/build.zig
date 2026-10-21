const std = @import("std");
const Build = @import("zx").Build;
const AddElementOptions = Build.AddElementOptions;

test "add element > pathname matches" {
    const all: AddElementOptions.Pathname = .{};
    try std.testing.expect(all.matches("/"));
    try std.testing.expect(all.matches("/docs"));

    const includes_only: AddElementOptions.Pathname = .{ .includes = &.{ "/docs", "/blog*" } };
    try std.testing.expect(includes_only.matches("/docs"));
    try std.testing.expect(includes_only.matches("/blog"));
    try std.testing.expect(includes_only.matches("/blog/post"));
    try std.testing.expect(!includes_only.matches("/"));

    const excludes: AddElementOptions.Pathname = .{ .excludes = &.{"/playground*"} };
    try std.testing.expect(excludes.matches("/"));
    try std.testing.expect(!excludes.matches("/playground"));
    try std.testing.expect(!excludes.matches("/playground/foo"));

    const both: AddElementOptions.Pathname = .{
        .includes = &.{"/examples*"},
        .excludes = &.{"/examples/secret"},
    };
    try std.testing.expect(both.matches("/examples"));
    try std.testing.expect(both.matches("/examples/api"));
    try std.testing.expect(!both.matches("/examples/secret"));
    try std.testing.expect(!both.matches("/docs"));
}

const BuildConfig = Build.BuildConfig;

test "build config > default arg omits every field" {
    const arg = try (BuildConfig{}).arg(std.testing.allocator);
    defer std.testing.allocator.free(arg);
    try std.testing.expectEqualStrings("-Dziex-config=.{}", arg);
}

test "build config > arg roundtrips through parse" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const config = BuildConfig{ .command = .dev, .incremental = true, .prerender = true, .port = 8080, .address = "0.0.0.0" };
    const arg = try config.arg(arena.allocator());
    const value = arg["-Dziex-config=".len..];

    var diagnostics: std.zon.parse.Diagnostics = undefined;
    const parsed = try BuildConfig.parse(arena.allocator(), value, &diagnostics);
    try std.testing.expectEqual(BuildConfig.Command.dev, parsed.command.?);
    try std.testing.expect(parsed.incremental);
    try std.testing.expect(parsed.prerender);
    try std.testing.expectEqual(@as(u16, 8080), parsed.port.?);
    try std.testing.expectEqualStrings("0.0.0.0", parsed.address.?);
}

test "build config > parse ignores unknown fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var diagnostics: std.zon.parse.Diagnostics = undefined;
    const parsed = try BuildConfig.parse(arena.allocator(), ".{ .command = .serve, .from_a_newer_cli = true }", &diagnostics);
    try std.testing.expectEqual(BuildConfig.Command.serve, parsed.command.?);
    try std.testing.expect(!parsed.prerender);
}

test "build config > parse rejects invalid zon" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var diagnostics: std.zon.parse.Diagnostics = undefined;
    try std.testing.expectError(error.ParseZon, BuildConfig.parse(arena.allocator(), ".{ .command = .nope }", &diagnostics));
}
