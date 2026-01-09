pub fn Route(ctx: zx.RouteContext) !void {
    try ctx.socket.upgrade(.{});
}

pub fn Socket(ctx: zx.SocketContext) !void {
    var count: usize = 0;
    while (count < 10) {
        const count_str = try std.fmt.allocPrint(ctx.arena, "count: {d} {s}", .{ count, ctx.message });
        try ctx.socket.write(count_str);
        count += 1;
        std.Thread.sleep(1 * std.time.ns_per_s);
    }
    try ctx.socket.write(ctx.message);
}

const zx = @import("zx");
const std = @import("std");
