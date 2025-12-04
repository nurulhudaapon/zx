const std = @import("std");
const tui = @import("../../tui/main.zig");
const Colors = tui.Colors;
const log = std.log.scoped(.cli);

const RESTART_COOLDOWN_NS = std.time.ns_per_ms * 10;

pub const BuildStats = struct {
    max_duration_ms: u64,

    pub fn init() BuildStats {
        return .{ .max_duration_ms = 0 };
    }

    /// Parse duration from string like "6s", "123ms", "45us", "1m"
    fn parseDuration(text: []const u8) ?u64 {
        if (text.len < 2) return null;

        // Find where the number ends and unit begins
        var num_end: usize = 0;
        while (num_end < text.len) : (num_end += 1) {
            const c = text[num_end];
            if (!std.ascii.isDigit(c) and c != '.') break;
        }

        if (num_end == 0) return null;

        const num_str = text[0..num_end];
        const unit = text[num_end..];

        const value = std.fmt.parseFloat(f64, num_str) catch return null;

        // Convert to milliseconds
        const ms = if (std.mem.eql(u8, unit, "s"))
            value * 1000.0
        else if (std.mem.eql(u8, unit, "ms"))
            value
        else if (std.mem.eql(u8, unit, "us"))
            value / 1000.0
        else if (std.mem.eql(u8, unit, "ns"))
            value / 1_000_000.0
        else if (std.mem.eql(u8, unit, "m"))
            value * 60_000.0
        else if (std.mem.eql(u8, unit, "h"))
            value * 3_600_000.0
        else
            return null;

        return @intFromFloat(ms);
    }

    /// Update stats by parsing a line from build summary
    pub fn parseLine(self: *BuildStats, line: []const u8) void {
        // Look for duration indicators: "6s", "123ms", etc.
        // They appear after status words like "success", "cached", "failure"
        var it = std.mem.tokenizeAny(u8, line, " \t");
        while (it.next()) |token| {
            if (parseDuration(token)) |duration_ms| {
                if (duration_ms > self.max_duration_ms) {
                    self.max_duration_ms = duration_ms;
                    log.debug("Found build duration: {d}ms from '{s}'", .{ duration_ms, token });
                }
            }
        }
    }
};

pub const BuildWatcher = struct {
    allocator: std.mem.Allocator,
    builder_stderr: std.fs.File,
    should_restart: bool,
    mutex: std.Thread.Mutex,
    first_build_done: bool,
    restart_pending: bool,
    last_restart_time_ns: i128,
    binary_path: []const u8,
    last_binary_mtime: i128,
    build_completed: bool,
    build_stats: BuildStats, // Parsed build statistics

    pub fn init(
        allocator: std.mem.Allocator,
        builder_stderr: std.fs.File,
        binary_path: []const u8,
        initial_mtime: i128,
    ) BuildWatcher {
        return .{
            .allocator = allocator,
            .builder_stderr = builder_stderr,
            .should_restart = false,
            .mutex = .{},
            .first_build_done = false,
            .restart_pending = false,
            .last_restart_time_ns = 0,
            .binary_path = binary_path,
            .last_binary_mtime = initial_mtime,
            .build_completed = false,
            .build_stats = BuildStats.init(),
        };
    }

    pub fn getBuildDurationMs(self: *BuildWatcher) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.build_stats.max_duration_ms;
    }

    pub fn shouldRestart(self: *BuildWatcher) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const result = self.should_restart;
        self.should_restart = false;
        self.build_completed = false;
        return result;
    }

    pub fn markRestartComplete(self: *BuildWatcher, new_mtime: i128) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.restart_pending = false;
        self.last_restart_time_ns = std.time.nanoTimestamp();
        self.last_binary_mtime = new_mtime;
    }
};

pub fn watchBuildOutput(watcher: *BuildWatcher) !void {
    var buf: [8192]u8 = undefined;
    var pattern_buf = std.ArrayList(u8).empty;
    defer pattern_buf.deinit(watcher.allocator);
    var line_buf = std.ArrayList(u8).empty;
    defer line_buf.deinit(watcher.allocator);

    log.debug("Build watcher thread started", .{});

    while (true) {
        const bytes_read = watcher.builder_stderr.read(&buf) catch |err| {
            if (err == error.EndOfStream) break;
            log.debug("Error reading stderr: {any}", .{err});
            continue;
        };
        if (bytes_read == 0) break;

        // Reset build stats when new build starts
        watcher.mutex.lock();
        const is_new_build = watcher.first_build_done and !watcher.build_completed;
        if (is_new_build) {
            watcher.build_stats = BuildStats.init();
            log.debug("Build started", .{});
        }
        watcher.mutex.unlock();

        // Process bytes line by line to parse build stats
        for (buf[0..bytes_read]) |byte| {
            if (byte == '\n') {
                // Process complete line
                if (line_buf.items.len > 0) {
                    watcher.mutex.lock();
                    watcher.build_stats.parseLine(line_buf.items);
                    watcher.mutex.unlock();
                }
                line_buf.clearRetainingCapacity();
            } else {
                try line_buf.append(watcher.allocator, byte);
            }
        }

        // Also accumulate to detect "Build Summary:"
        try pattern_buf.appendSlice(watcher.allocator, buf[0..bytes_read]);

        if (pattern_buf.items.len > 1024) {
            const keep_from = pattern_buf.items.len - 512;
            std.mem.copyForwards(u8, pattern_buf.items[0..512], pattern_buf.items[keep_from..]);
            pattern_buf.shrinkRetainingCapacity(512);
        }

        // Detect build completion
        if (std.mem.indexOf(u8, pattern_buf.items, "Build Summary:") != null) {
            const now = std.time.nanoTimestamp();

            log.debug("Build Summary detected", .{});

            const stat = std.fs.cwd().statFile(watcher.binary_path) catch |err| {
                log.debug("Failed to stat binary: {any}", .{err});
                pattern_buf.clearRetainingCapacity();
                continue;
            };

            watcher.mutex.lock();

            const binary_changed = stat.mtime != watcher.last_binary_mtime;
            const already_handled = watcher.build_completed;

            if (!already_handled and watcher.first_build_done) {
                if (binary_changed and !watcher.restart_pending) {
                    const time_since_last_restart = now - watcher.last_restart_time_ns;

                    if (time_since_last_restart >= RESTART_COOLDOWN_NS) {
                        watcher.should_restart = true;
                        watcher.restart_pending = true;
                        watcher.last_binary_mtime = stat.mtime;
                        watcher.build_completed = true;
                        log.debug("Build completed, triggering restart", .{});
                    }
                }
            } else if (!watcher.first_build_done) {
                watcher.first_build_done = true;
                watcher.last_binary_mtime = stat.mtime;
                watcher.last_restart_time_ns = std.time.nanoTimestamp();
                log.debug("First build detected", .{});
            }

            watcher.mutex.unlock();

            pattern_buf.clearRetainingCapacity();
        }
    }
}
