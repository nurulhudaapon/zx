const std = @import("std");
const BuildConfig = @import("../build/init/BuildConfig.zig");

const util = @import("shared/util.zig");
const context = @import("shared/context.zig");
const Diagnostics = @import("dev/Diagnostics.zig");
const tui = @import("../tui/main.zig");
const cli_args = @import("root.zig");
const export_cmd = @import("export.zig");

const CommandContext = context.CommandContext;
const Colors = tui.Colors;
const log = std.log.scoped(.cli);
pub const command = cli_args.build;

pub fn run(ctx: CommandContext, args: anytype) !void {
    const app = ctx.app;
    const io = app.io;
    const allocator = ctx.allocator;

    if (args.static) {
        // Export runs the built app on this machine, so it can't be cross-compiled.
        if (args.target.len > 0 and !std.mem.eql(u8, args.target, "native")) {
            try ctx.writer.print("{s}error:{s} --static builds for this machine and can't be combined with --target={s}\n", .{ Colors.red, Colors.reset, args.target });
            std.process.exit(1);
        }
        const release = try std.fmt.allocPrint(allocator, "--release={s}", .{if (args.release.len > 0) args.release else "small"});
        defer allocator.free(release);
        return export_cmd.exportSite(ctx, .{
            .outdir = args.outdir,
            .binpath = args.binpath,
            .@"zig-path" = args.@"zig-path",
            .@"build-args" = if (args.@"build-args".len > 0) args.@"build-args" else release,
            .@"prerendered-only" = args.@"prerendered-only",
        });
    }

    var build_args = std.ArrayList([]const u8).empty;
    defer build_args.deinit(allocator);
    try build_args.appendSlice(allocator, &.{ args.@"zig-path", "build" });

    const target_arg = if (args.target.len > 0) try std.fmt.allocPrint(allocator, "-Dtarget={s}", .{args.target}) else null;
    defer if (target_arg) |t| allocator.free(t);
    if (target_arg) |t| try build_args.append(allocator, t);
    const release_arg = if (args.release.len > 0) try std.fmt.allocPrint(allocator, "--release={s}", .{args.release}) else null;
    defer if (release_arg) |r| allocator.free(r);
    if (release_arg) |r| try build_args.append(allocator, r);
    const config_arg = if (args.prerender) try (BuildConfig{ .prerender = true }).arg(allocator) else null;
    defer if (config_arg) |c| allocator.free(c);
    if (config_arg) |c| try build_args.append(allocator, c);

    var i_build_args = std.mem.splitSequence(u8, args.@"build-args", " ");
    while (i_build_args.next()) |arg| {
        const trimmed_arg = std.mem.trim(u8, arg, " ");
        if (std.mem.eql(u8, trimmed_arg, "")) continue;
        try build_args.append(allocator, trimmed_arg);
    }

    var system = try util.spawnZig(io, .{
        .argv = build_args.items,
        .environ_map = app.environ_map,
        .stderr = .pipe,
        .stdout = .ignore,
    });
    defer system.kill(io);

    var spinner = ctx.spinner;
    spinner.updateStyle(.{ .frames = tui.Spinner.SpinnerStyles.dots2, .refresh_rate_ms = 80 });
    try spinner.start("{s}Building...{s}", .{ Colors.cyan, Colors.reset });

    const start_ts = std.Io.Timestamp.now(io, .awake);

    const formatted = formatBuildErrors(io, allocator, &system) catch |err| {
        spinner.fail("{s}Build failed{s}", .{ Colors.red, Colors.reset }) catch {};
        return err;
    };
    defer if (formatted) |f| allocator.free(f);

    const term = try system.wait(io);
    const elapsed_ms: u64 = @intCast(start_ts.durationTo(std.Io.Timestamp.now(io, .awake)).toMilliseconds());
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ms)) / 1000.0;

    const failed = switch (term) {
        .exited => |code| code != 0,
        else => true,
    };

    if (failed) {
        try spinner.fail("{s}Build failed {s}({d:.2}s){s}", .{ Colors.red, Colors.gray, elapsed_s, Colors.reset });
        if (formatted) |f| try ctx.writer.writeAll(f);
        switch (term) {
            .exited => |code| std.process.exit(code),
            else => std.process.exit(1),
        }
    }

    try spinner.succeed("{s}Built {s}({d:.2}s){s}", .{ Colors.green, Colors.gray, elapsed_s, Colors.reset });
    if (formatted) |f| try ctx.writer.writeAll(f);
}

fn formatBuildErrors(
    io: std.Io,
    allocator: std.mem.Allocator,
    system: *std.process.Child,
) !?[]u8 {
    var raw_buf: [8192]u8 = undefined;
    var streaming_reader = system.stderr.?.readerStreaming(io, &raw_buf);
    return Diagnostics.formatFromReader(allocator, &streaming_reader.interface, .{});
}
