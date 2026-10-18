// Child process trees. On POSIX each child leads its own process group, so
// `-pid` reaches its descendants and the terminal's Ctrl+C reaches only us.

const std = @import("std");
const builtin = @import("builtin");

const Child = std.process.Child;
const Io = std.Io;
const posix = std.posix;
const is_windows = builtin.os.tag == .windows;

pub const own_group: ?posix.pid_t = if (is_windows) null else 0;

pub fn killTree(id: Child.Id) void {
    if (comptime is_windows) {
        _ = std.os.windows.ntdll.NtTerminateProcess(id, @fromBackingInt(1));
    } else {
        _ = posix.system.kill(-id, .KILL);
    }
}

pub fn stop(child: *Child, io: Io, timeout_ms: u64) void {
    const id = child.id orelse return;
    if (comptime is_windows) killTree(id) else _ = posix.system.kill(-id, .TERM);
    waitOrKill(child, io, timeout_ms);
}

pub fn waitOrKill(child: *Child, io: Io, timeout_ms: u64) void {
    const id = child.id orelse return;
    var watchdog = io.concurrent(killAfter, .{ io, id, timeout_ms }) catch {
        killTree(id);
        _ = child.wait(io) catch {};
        return;
    };
    _ = child.wait(io) catch {};
    watchdog.cancel(io);
}

fn killAfter(io: Io, id: Child.Id, timeout_ms: u64) void {
    io.sleep(.fromMilliseconds(@intCast(timeout_ms)), .awake) catch return;
    killTree(id);
}

/// Under `zig build dev` the build runner shares our process group and dies on
/// Ctrl+C at once, so the shell prompt would print before our shutdown output.
/// Leading our own foreground group keeps Ctrl+C to us and the runner waiting.
pub const terminal = struct {
    const pid_t = if (is_windows) i32 else posix.pid_t;

    var tty: ?posix.fd_t = null;
    var prev_pgrp: pid_t = 0;

    pub fn take() void {
        if (comptime is_windows) return;
        const pid = posix.system.getpid();
        const pgrp = sys.getpgid();
        if (pgrp == pid) return;
        for ([_]Io.File{ .stdin(), .stdout(), .stderr() }) |file| {
            if (sys.tcgetpgrp(file.handle) != pgrp) continue;
            if (posix.errno(posix.system.setpgid(0, 0)) != .SUCCESS) return;
            // Ctrl+Z would stop only us, hanging the shell that waits on the runner.
            ignore(.TSTP, null);
            if (!setForeground(file.handle, pid)) {
                _ = posix.system.setpgid(0, pgrp);
                return;
            }
            tty = file.handle;
            prev_pgrp = pgrp;
            return;
        }
    }

    pub fn held() bool {
        return tty != null;
    }

    /// Async-signal-safe.
    pub fn release() void {
        if (comptime is_windows) return;
        _ = setForeground(tty orelse return, prev_pgrp);
        tty = null;
    }

    fn setForeground(fd: posix.fd_t, pgrp: pid_t) bool {
        var prev_ttou: posix.Sigaction = undefined;
        ignore(.TTOU, &prev_ttou);
        defer posix.sigaction(.TTOU, &prev_ttou, null);
        return sys.tcsetpgrp(fd, pgrp);
    }

    fn ignore(signal: posix.SIG, prev: ?*posix.Sigaction) void {
        const act: posix.Sigaction = .{ .handler = .{ .handler = posix.SIG.IGN }, .mask = posix.sigemptyset(), .flags = 0 };
        posix.sigaction(signal, &act, prev);
    }

    /// `std.posix.tcgetpgrp`/`tcsetpgrp` lack `std.c` bindings, so they only build for Linux without libc.
    const sys = if (builtin.os.tag == .linux) struct {
        const linux = std.os.linux;
        fn getpgid() pid_t {
            return @bitCast(@as(u32, @truncate(linux.getpgid(0))));
        }
        fn tcgetpgrp(fd: posix.fd_t) pid_t {
            var pgrp: pid_t = -1;
            return if (linux.errno(linux.tcgetpgrp(fd, &pgrp)) == .SUCCESS) pgrp else -1;
        }
        fn tcsetpgrp(fd: posix.fd_t, pgrp: pid_t) bool {
            return linux.errno(linux.tcsetpgrp(fd, &pgrp)) == .SUCCESS;
        }
    } else struct {
        const c = struct {
            extern "c" fn getpgid(pid: pid_t) pid_t;
            extern "c" fn tcgetpgrp(fd: posix.fd_t) pid_t;
            extern "c" fn tcsetpgrp(fd: posix.fd_t, pgrp: pid_t) c_int;
        };
        const tcgetpgrp = c.tcgetpgrp;
        fn getpgid() pid_t {
            return c.getpgid(0);
        }
        fn tcsetpgrp(fd: posix.fd_t, pgrp: pid_t) bool {
            return c.tcsetpgrp(fd, pgrp) == 0;
        }
    };
};
