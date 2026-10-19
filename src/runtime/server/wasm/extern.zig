const std = @import("std");
const builtin = @import("builtin");

const is_wasm = builtin.cpu.arch.isWasm();

const import = struct {
    extern "__zx_ws" fn ws_upgrade() void;
    extern "__zx_ws" fn ws_write(ptr: [*]const u8, len: usize) void;
    extern "__zx_ws" fn ws_close(code: u16, reason_ptr: [*]const u8, reason_len: usize) void;
    extern "__zx_ws" fn ws_recv(buf_ptr: [*]u8, buf_max: usize) i32;
    extern "__zx_ws" fn ws_subscribe(topic_ptr: [*]const u8, topic_len: usize) void;
    extern "__zx_ws" fn ws_unsubscribe(topic_ptr: [*]const u8, topic_len: usize) void;
    extern "__zx_ws" fn ws_publish(topic_ptr: [*]const u8, topic_len: usize, data_ptr: [*]const u8, data_len: usize) usize;
    extern "__zx_ws" fn ws_is_subscribed(topic_ptr: [*]const u8, topic_len: usize) i32;

    extern "__zx_http" fn commit(status: u16, meta_ptr: [*]const u8, meta_len: usize) void;
    extern "__zx_http" fn write(ptr: [*]const u8, len: usize) void;
    extern "__zx_http" fn end() void;

    extern "__zx" fn _log(level: u8, ptr: [*]const u8, len: usize) void;

    extern "__zx_sys" fn park() void;
};

pub const ws = struct {
    pub fn upgrade() void {
        if (is_wasm) import.ws_upgrade();
    }

    pub fn write(data: []const u8) void {
        if (is_wasm) import.ws_write(data.ptr, data.len);
    }

    pub fn close(code: u16, reason: []const u8) void {
        if (is_wasm) import.ws_close(code, reason.ptr, reason.len);
    }

    // Null once the socket is closed.
    pub fn recv(buf: []u8) ?usize {
        if (!is_wasm) return null;
        const n = import.ws_recv(buf.ptr, buf.len);
        return if (n < 0) null else @intCast(n);
    }

    pub fn subscribe(topic: []const u8) void {
        if (is_wasm) import.ws_subscribe(topic.ptr, topic.len);
    }

    pub fn unsubscribe(topic: []const u8) void {
        if (is_wasm) import.ws_unsubscribe(topic.ptr, topic.len);
    }

    pub fn publish(topic: []const u8, data: []const u8) usize {
        return if (is_wasm) import.ws_publish(topic.ptr, topic.len, data.ptr, data.len) else 0;
    }

    pub fn isSubscribed(topic: []const u8) bool {
        if (!is_wasm) return false;
        return import.ws_is_subscribed(topic.ptr, topic.len) != 0;
    }
};

pub const http = struct {
    // meta: {"streaming":bool,"headers":[[name,value],...]}
    pub fn commit(status: u16, meta: []const u8) void {
        if (is_wasm) import.commit(status, meta.ptr, meta.len);
    }

    pub fn write(bytes: []const u8) void {
        if (is_wasm and bytes.len > 0) import.write(bytes.ptr, bytes.len);
    }

    pub fn end() void {
        if (is_wasm) import.end();
    }
};

pub const sys = struct {
    // Never resumes; the host then serves requests via `__zx_serve`.
    pub fn park() void {
        if (is_wasm) import.park();
    }
};

pub fn log(level: std.log.Level, message: []const u8) void {
    if (!is_wasm) return;
    const code: u8 = switch (level) {
        .err => 0,
        .warn => 1,
        .info => 2,
        .debug => 3,
    };
    import._log(code, message.ptr, message.len);
}
