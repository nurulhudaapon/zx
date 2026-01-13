pub fn PUT(ctx: zx.RouteContext) !void {
    ctx.response.setBody("Hello, World!");
}

const zx = @import("zx");
