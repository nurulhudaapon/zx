// SIGINT/SIGTERM (POSIX) and console Ctrl+C/Break/Close (Windows). The first
// signal runs the handler on an ordinary thread; a second one force-exits.

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const windows = std.os.windows;

const native_os = builtin.os.tag;
const is_windows = native_os == .windows;
const is_posix = switch (native_os) {
    .linux, .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos, .freebsd, .netbsd, .dragonfly, .openbsd, .serenity, .illumos => true,
    else => false,
};

pub const Handler = *const fn (signal: posix.SIG) void;

pub const InstallError = error{
    AlreadyInstalled,
    Unexpected,
} || std.Thread.SpawnError;

var handler: ?Handler = null;
var on_force: ?*const fn () void = null;
var received: std.atomic.Value(bool) = .init(false);

var wake_r: posix.fd_t = -1;
var wake_w: posix.fd_t = -1;
var dispatcher: ?std.Thread = null;
var prev_int: posix.Sigaction = undefined;
var prev_term: posix.Sigaction = undefined;

pub fn install(on_signal: Handler) InstallError!void {
    if (handler != null) return error.AlreadyInstalled;
    handler = on_signal;
    errdefer handler = null;
    received.store(false, .release);

    if (comptime is_windows) {
        if (SetConsoleCtrlHandler(onConsoleCtrl, .TRUE) == .FALSE) return error.Unexpected;
    } else if (comptime is_posix) {
        const fds = try createPipe();
        wake_r = fds[0];
        wake_w = fds[1];
        errdefer closePipe();
        dispatcher = try std.Thread.spawn(.{}, dispatch, .{});

        const act: posix.Sigaction = .{
            .handler = .{ .handler = onPosixSignal },
            .mask = posix.sigemptyset(),
            .flags = posix.SA.RESTART,
        };
        posix.sigaction(.INT, &act, &prev_int);
        posix.sigaction(.TERM, &act, &prev_term);
    }
}

/// Runs before a forced exit; on POSIX in signal context (async-signal-safe only).
pub fn setForceHandler(f: ?*const fn () void) void {
    on_force = f;
}

/// Must not be called from the handler itself.
pub fn uninstall() void {
    if (handler == null) return;

    if (comptime is_windows) {
        _ = SetConsoleCtrlHandler(onConsoleCtrl, .FALSE);
    } else if (comptime is_posix) {
        posix.sigaction(.INT, &prev_int, null);
        posix.sigaction(.TERM, &prev_term, null);
        _ = posix.system.close(wake_w);
        wake_w = -1;
        if (dispatcher) |t| t.join();
        dispatcher = null;
        closePipe();
    }

    handler = null;
    on_force = null;
}

pub fn exit(signal: posix.SIG) noreturn {
    exitWith(128 +% @as(u8, @intCast(@backingInt(signal))));
}

/// Async-signal-safe; skips atexit hooks and other threads.
pub fn exitWith(code: u8) noreturn {
    if (comptime native_os == .linux) {
        std.os.linux.exit_group(code);
    } else if (comptime is_posix) {
        std.c._exit(code);
    } else {
        std.process.exit(code);
    }
}

fn forceExit(signal: posix.SIG) noreturn {
    if (on_force) |f| f();
    exit(signal);
}

fn onPosixSignal(signal: posix.SIG) callconv(.c) void {
    if (received.swap(true, .acq_rel)) forceExit(signal);
    const byte: [1]u8 = .{@intCast(@backingInt(signal))};
    _ = posix.system.write(wake_w, &byte, 1);
}

fn dispatch() void {
    var byte: [1]u8 = undefined;
    while (true) {
        const rc = posix.system.read(wake_r, &byte, 1);
        switch (posix.errno(rc)) {
            .SUCCESS => {
                if (rc == 0) return;
                handler.?(@fromBackingInt(byte[0]));
            },
            .INTR => continue,
            else => return,
        }
    }
}

fn onConsoleCtrl(ctrl_type: windows.DWORD) callconv(.winapi) windows.BOOL {
    switch (ctrl_type) {
        0, 1, 2 => { // CTRL_C, CTRL_BREAK, CTRL_CLOSE
            if (received.swap(true, .acq_rel)) forceExit(.INT);
            handler.?(.INT);
            return .TRUE;
        },
        else => return .FALSE,
    }
}

fn createPipe() InstallError![2]posix.fd_t {
    var fds: [2]posix.fd_t = undefined;
    if (@TypeOf(posix.system.pipe2) != void) {
        if (posix.errno(posix.system.pipe2(&fds, .{ .CLOEXEC = true })) != .SUCCESS) return error.Unexpected;
        return fds;
    }
    if (posix.errno(posix.system.pipe(&fds)) != .SUCCESS) return error.Unexpected;
    for (fds) |fd| _ = posix.system.fcntl(fd, posix.F.SETFD, @as(u32, posix.FD_CLOEXEC));
    return fds;
}

fn closePipe() void {
    if (wake_r >= 0) _ = posix.system.close(wake_r);
    if (wake_w >= 0) _ = posix.system.close(wake_w);
    wake_r = -1;
    wake_w = -1;
}

extern "kernel32" fn SetConsoleCtrlHandler(
    HandlerRoutine: ?*const fn (windows.DWORD) callconv(.winapi) windows.BOOL,
    Add: windows.BOOL,
) callconv(.winapi) windows.BOOL;
