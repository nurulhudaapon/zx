const zx = @import("zx");

pub fn Proxy(ctx: *zx.ProxyContext) !void {
    ctx.response.redirect("https://ssr.ziex.dev/examples", null);
    ctx.abort();
}
