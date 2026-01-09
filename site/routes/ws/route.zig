const SocketData = struct {
    user_id: u32,
    is_admin: bool,
};

pub fn GET(ctx: zx.RouteContext) !void {
    try ctx.socket.upgrade(SocketData{
        .user_id = 123,
        .is_admin = true,
    });
}

pub fn Socket(ctx: zx.SocketCtx(SocketData)) !void {
    var count: usize = 0;

    while (count < 10) : (count += 1) {
        std.Thread.sleep(1 * std.time.ns_per_s);

        const count_str = try std.fmt.allocPrint(
            ctx.allocator,
            "Socket: {d}, user_id: {d}, is_admin: {}, you said: {s}",
            .{ count, ctx.data.user_id, ctx.data.is_admin, ctx.message },
        );

        try ctx.socket.write(count_str);
    }
    ctx.socket.close();
}

const zx = @import("zx");
const std = @import("std");
