const zx = @import("zx");

pub const routes = [_]zx.App.Route{
    .{ .path = "/", .route = @import("routes/root.zig") },
    .{ .path = "/echo", .route = @import("routes/echo.zig") },
    .{ .path = "/headers", .route = @import("routes/headers.zig") },
    .{ .path = "/json", .route = @import("routes/json.zig") },
};

pub const RoutePaths = enum {
    @"/",
    @"/echo",
    @"/headers",
    @"/json",
};

pub const components = [_]zx.client.ComponentMeta{};
