pub fn GET(ctx: zx.RouteContext) !void {
    const uname = ctx.request.cookies.get("username") orelse "";
    if (uname.len == 0) {
        ctx.response.setStatus(.bad_request);
        return ctx.response.setBody("Missing username cookie");
    }

    try ctx.socket.upgrade(SocketData{
        .username = uname,
    });
}

pub fn SocketOpen(ctx: zx.SocketOpenCtx(SocketData)) !void {
    ctx.socket.configure(.{ .publish_to_self = true });
    ctx.socket.subscribe(CHAT_TOPIC);

    _ = ctx.socket.publish(CHAT_TOPIC, try ctx.fmt(
        "system: {s} joined the chat",
        .{ctx.data.username},
    ));

    for (messages.items) |msg| {
        try ctx.socket.write(try ctx.fmt(
            "{s}: {s}",
            .{ msg.username, msg.text },
        ));
    }
}

pub fn Socket(ctx: zx.SocketCtx(SocketData)) !void {
    const formatted = try ctx.fmt(
        "{s}: {s}",
        .{ ctx.data.username, ctx.message },
    );

    _ = ctx.socket.publish(CHAT_TOPIC, formatted);

    messages.append(ctx.allocator, .{
        .text = ctx.allocator.dupe(u8, ctx.message) catch return,
        .username = ctx.allocator.dupe(u8, ctx.data.username) catch return,
    }) catch return;
}

pub fn SocketClose(ctx: zx.SocketCloseCtx(SocketData)) void {
    const msg = ctx.fmt(
        "system: {s} left the chat",
        .{ctx.data.username},
    ) catch return;
    _ = ctx.socket.publish(CHAT_TOPIC, msg);
}

var messages = std.ArrayList(Message).empty;

const CHAT_TOPIC = "chat-room";
const Message = struct { text: []const u8, username: []const u8 };
const SocketData = struct { username: []const u8 };

const std = @import("std");
const zx = @import("zx");
