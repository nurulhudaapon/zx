pub const Console = struct {
    ref: js.Object,

    pub fn init() Console {
        return .{
            .ref = js.global.get(js.Object, "console") catch @panic("Console not found"),
        };
    }

    pub fn deinit(self: Console) void {
        self.ref.deinit();
    }

    pub fn log(self: Console, args: anytype) void {
        self.ref.call(void, "log", args) catch @panic("Failed to call console.log");
    }

    pub fn str(self: Console, data: []const u8) void {
        self.ref.call(void, "log", .{js.string(data)}) catch @panic("Failed to call console.log");
    }

    pub fn @"error"(self: Console, args: anytype) void {
        self.ref.call(void, "error", args) catch @panic("Failed to call console.error");
    }

    pub fn warn(self: Console, args: anytype) void {
        self.ref.call(void, "warn", args) catch @panic("Failed to call console.warn");
    }

    pub fn info(self: Console, args: anytype) void {
        self.ref.call(void, "info", args) catch @panic("Failed to call console.info");
    }

    pub fn debug(self: Console, args: anytype) void {
        self.ref.call(void, "debug", args) catch @panic("Failed to call console.debug");
    }

    pub fn table(self: Console, args: anytype) void {
        self.ref.call(void, "table", args) catch @panic("Failed to call console.table");
    }
};

pub const Event = struct {
    const EventTarget = struct {
        value: []const u8,
    };

    id: u64,
    ref: js.Object,

    target: EventTarget,
    data: ?[]const u8 = null,

    pub fn idInit(allocator: std.mem.Allocator, id: u64) !Event {
        const obj: js.Object = try js.global.get(js.Object, "_zx");
        const ob_val: js.Object = try obj.get(js.Object, "events");

        const current_event: js.Object = try ob_val.call(js.Object, "at", .{id});
        const target: js.Object = try current_event.get(js.Object, "target");
        const target_value: []const u8 = try target.getAlloc(js.String, allocator, "value");

        const event_target: EventTarget = .{ .value = target_value };
        const event_data: ?[]const u8 = current_event.getAlloc(js.String, allocator, "data") catch null;

        return .{
            .id = id,
            .ref = current_event,
            .target = event_target,
            .data = event_data,
        };
    }

    pub fn deinit(self: Event) void {
        self.ref.deinit();
    }
};

pub fn eval(T: type, code: []const u8) !T {
    return try js.global.call(T, "eval", .{js.string(code)});
}

pub const Document = @import("bom/dom.zig").Document;

const std = @import("std");
const js = @import("js");
