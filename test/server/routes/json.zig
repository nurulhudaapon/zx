const zx = @import("zx");

pub fn GET(ctx: zx.RouteContext) !void {
    try ctx.response.json(.{ .ok = true, .n = 42 }, .{});
}
