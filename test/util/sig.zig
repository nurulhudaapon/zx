const std = @import("std");
const builtin = @import("builtin");
const sig = @import("zx").util.sig;

const posix = std.posix;
const is_posix = switch (builtin.os.tag) {
    .linux, .macos, .ios, .watchos, .tvos, .visionos, .driverkit, .maccatalyst, .freebsd, .netbsd, .dragonfly, .openbsd => true,
    else => false,
};

fn noop(_: posix.SIG) void {}

fn sleepMs(ms: u32) void {
    var req: posix.timespec = .{ .sec = @intCast(ms / 1000), .nsec = @intCast((ms % 1000) * std.time.ns_per_ms) };
    _ = posix.system.nanosleep(&req, &req);
}

fn forkStatus(comptime body: fn () void) !u32 {
    const rc = posix.system.fork();
    if (posix.errno(rc) != .SUCCESS) return error.SkipZigTest;
    if (rc == 0) {
        body();
        std.process.exit(0);
    }
    var status: i32 = 0;
    while (true) switch (posix.errno(posix.system.waitpid(@intCast(rc), &status, 0))) {
        .SUCCESS => return @bitCast(status),
        .INTR => continue,
        else => return error.TestUnexpectedResult,
    };
}

test "signal > runs handler" {
    if (comptime !is_posix) return error.SkipZigTest;

    const Hit = struct {
        var signal: std.atomic.Value(u8) = .init(0);
        fn handler(s: posix.SIG) void {
            signal.store(@intCast(@backingInt(s)), .release);
        }
    };
    Hit.signal.store(0, .release);

    try sig.install(Hit.handler);
    defer sig.uninstall();
    try posix.raise(.TERM);

    var waited: u32 = 0;
    while (Hit.signal.load(.acquire) == 0 and waited < 1000) : (waited += 10) {
        std.Io.sleep(std.testing.io, .fromMilliseconds(10), .awake) catch {};
    }
    try std.testing.expectEqual(@backingInt(posix.SIG.TERM), Hit.signal.load(.acquire));
}

test "signal > double install" {
    try sig.install(noop);
    defer sig.uninstall();
    try std.testing.expectError(error.AlreadyInstalled, sig.install(noop));
}

test "signal > reinstall" {
    try sig.install(noop);
    sig.uninstall();
    try sig.install(noop);
    sig.uninstall();
}

test "signal > second signal force-exits" {
    if (comptime !is_posix) return error.SkipZigTest;

    const status = try forkStatus(struct {
        fn stuck(_: posix.SIG) void {
            while (true) sleepMs(1000);
        }
        fn body() void {
            sig.install(stuck) catch std.process.exit(2);
            posix.raise(.INT) catch {};
            sleepMs(50);
            posix.raise(.INT) catch {};
            sleepMs(5000);
            std.process.exit(3);
        }
    }.body);

    try std.testing.expect(posix.W.IFEXITED(status));
    try std.testing.expectEqual(@as(u8, 130), posix.W.EXITSTATUS(status));
}

test "signal > force handler" {
    if (comptime !is_posix) return error.SkipZigTest;

    const status = try forkStatus(struct {
        fn stuck(_: posix.SIG) void {
            while (true) sleepMs(1000);
        }
        fn force() void {
            std.c._exit(42);
        }
        fn body() void {
            sig.install(stuck) catch std.process.exit(2);
            sig.setForceHandler(force);
            posix.raise(.INT) catch {};
            sleepMs(50);
            posix.raise(.INT) catch {};
            sleepMs(5000);
            std.process.exit(3);
        }
    }.body);

    try std.testing.expect(posix.W.IFEXITED(status));
    try std.testing.expectEqual(@as(u8, 42), posix.W.EXITSTATUS(status));
}

test "signal > exit code" {
    if (comptime !is_posix) return error.SkipZigTest;

    const status = try forkStatus(struct {
        fn body() void {
            sig.exit(.TERM);
        }
    }.body);

    try std.testing.expect(posix.W.IFEXITED(status));
    try std.testing.expectEqual(@as(u8, 128 + 15), posix.W.EXITSTATUS(status));
}
