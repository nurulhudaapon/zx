const zx = @import("zx");

pub fn GET(ctx: zx.RouteContext) !void {
    const value = ctx.request.headers.get("x-test") orelse "";
    ctx.response.headers.set("x-echo", value);
    ctx.response.text(value);
}
