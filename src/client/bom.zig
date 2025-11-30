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
};

pub const Event = struct {
    const EventTarget = struct {
        value: []const u8,
    };
    _count: i32,

    object: js.Object,
    target: EventTarget,
    data: ?[]const u8 = null,

    pub fn idxInit(allocator: std.mem.Allocator, idx: i64) !Event {
        const console = Console.init();
        defer console.deinit();

        const obj: js.Object = try js.global.get(js.Object, "_zx");
        defer obj.deinit();

        const ob_val: js.Object = try obj.get(js.Object, "events");
        defer ob_val.deinit();

        const count = try ob_val.get(i32, "length");

        const current_event: js.Object = try ob_val.call(js.Object, "at", .{idx});
        defer current_event.deinit();

        const target = try current_event.get(js.Object, "target");
        defer target.deinit();

        console.log(.{ js.string("Target: "), target });

        const target_value: []const u8 = target.getAlloc(js.String, allocator, "value") catch |err| {
            console.log(.{ js.string("Error: "), err });
            return err;
        };
        console.log(.{ js.string("Target Value: "), js.string(target_value) });

        const event_target: EventTarget = .{
            .value = target_value,
        };

        const event_data: ?[]const u8 = current_event.getAlloc(js.String, allocator, "data") catch null;

        return .{
            ._count = count,
            .target = event_target,
            .data = event_data,
            .object = current_event,
        };
    }
};

pub const Document = @import("bom/dom.zig").Document;

const std = @import("std");
const js = @import("js");
