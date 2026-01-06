const meta = @import("zx_meta").meta;
const std = @import("std");
const zx = @import("zx");
const builtin = @import("builtin");

const config = zx.App.Config{ .server = .{}, .meta = meta };

pub fn main() !void {
    if (builtin.os.tag == .freestanding) return;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const app = try zx.App.init(allocator, config);
    defer app.deinit();

    app.info();
    try app.start();
}

var client = zx.Client.init(
    zx.client_allocator,
    .{ .components = &@import("zx_components").components },
);

export fn mainClient() void {
    client.info();
    client.renderAll();
}
