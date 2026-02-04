//! Routing contexts for page, layout, error, and not-found handlers.
//! This module is backend-agnostic - no httpz dependency.

const std = @import("std");
const Request = @import("Request.zig");
const Response = @import("Response.zig");

/// Base context structure that provides access to request/response objects and allocators.
/// This is the foundation for both PageContext and LayoutContext, providing common functionality
/// for handling HTTP requests and managing memory allocation.
///
/// The type parameter `H` follows the httpz pattern and can be:
/// - `void`: No app context
/// - A struct type: App context stored by value (e.g., `BaseContext(AppCtx)`)
/// - A pointer type: App context stored by pointer (e.g., `BaseContext(*AppCtx)`)
pub fn BaseContext(comptime H: type) type {
    // Extract the underlying app context type, following httpz pattern
    // This is useful when H is a pointer - we get the child type
    _ = switch (@typeInfo(H)) {
        .@"struct" => H,
        .pointer => |ptr| ptr.child,
        .void => void,
        else => @compileError("BaseContext app type must be a struct, pointer to struct, or void, got: " ++ @tagName(@typeInfo(H))),
    };

    const AppFieldType = if (H == void) ?*const anyopaque else H;

    return struct {
        const Self = @This();
        /// Application context data:
        /// - For void: type-erased pointer for internal routing
        /// - For pointer types: stores the pointer directly
        /// - For value types: stores the value directly
        app: AppFieldType = if (H == void) null else undefined,

        /// The HTTP request object (backend-agnostic)
        /// Provides access to headers, body, query params, form data, cookies, etc.
        request: Request,

        /// The HTTP response object (backend-agnostic)
        /// Used to set status, headers, body, and cookies.
        response: Response,

        /// Global allocator passed from the app, only cleared when the app is deinitialized.
        /// Should be used for allocating memory that needs to persist across requests.
        /// Make sure to free the memory on your own that is allocated with this allocator.
        allocator: std.mem.Allocator,

        /// Allocator for allocating memory that needs to be freed after the request is processed.
        /// This allocator is cleared automatically when the request is processed, so you don't need
        /// to manually free memory allocated with this allocator. Use this for temporary allocations
        /// that are only needed during request processing.
        arena: std.mem.Allocator,

        /// Optional parent context, used for nested layouts or hierarchical context passing
        parent_ctx: ?*Self = null,

        /// Initialize a new BaseContext with the given request, response, and allocator.
        /// For void types, app defaults to {}. For custom types, app is undefined until set.
        pub fn init(request: Request, response: Response, alloc: std.mem.Allocator) Self {
            return .{
                .request = request,
                .response = response,
                .allocator = alloc,
                .arena = request.arena,
            };
        }

        /// Initialize a new BaseContext with a type-erased app context pointer.
        /// Used by the handler to pass the app context to page functions.
        pub fn initWithAppPtr(app_ptr: ?*const anyopaque, request: Request, response: Response, alloc: std.mem.Allocator) Self {
            // Convert the type-erased pointer to the appropriate AppFieldType:
            // - void: store the pointer directly for routing
            // - pointer: cast to the pointer type
            // - value: cast to pointer and dereference
            const app: AppFieldType = if (H == void)
                app_ptr
            else if (@typeInfo(H) == .pointer)
                @ptrCast(@alignCast(app_ptr))
            else
                (@as(*const H, @ptrCast(@alignCast(app_ptr)))).*;

            return .{
                .app = app,
                .request = request,
                .response = response,
                .allocator = alloc,
                .arena = request.arena,
            };
        }

        /// Initialize a new BaseContext with app context data.
        /// Use this when you need to pass custom application data to handlers.
        pub fn initWithApp(app: H, request: Request, response: Response, alloc: std.mem.Allocator) Self {
            return .{
                .app = app,
                .request = request,
                .response = response,
                .allocator = alloc,
                .arena = request.arena,
            };
        }

        /// Deinitialize the context, freeing any resources allocated with the global allocator.
        /// Note: The arena allocator is automatically cleaned up by the request handler.
        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self);
        }
    };
}

/// Context passed to page components. Provides access to the current HTTP request and response,
/// as well as allocators for memory management.
///
/// Usage in a page component:
/// ```zig
/// pub fn Page(ctx: zx.PageContext) zx.Component {
///     const allocator = ctx.arena; // Use arena for temporary allocations
///     // Access request data via MDN-compliant API
///     const method = ctx.request.method;
///     const url = ctx.request.url;
///     // Render component
///     return <div>Hello</div>;
/// }
/// ```
pub const PageContext = BaseContext(void);
pub fn PageCtx(comptime DataType: type) type {
    return BaseContext(DataType);
}

/// Context passed to layout components. Provides access to the current HTTP request and response,
/// as well as allocators for memory management. Layouts wrap page components and can be nested.
///
/// Usage in a layout component:
/// ```zig
/// pub fn Layout(ctx: zx.LayoutContext, children: zx.Component) zx.Component {
///     return (
///         <html>
///             <head><title>My App</title></head>
///             <body>{children}</body>
///         </html>
///     );
/// }
/// ```
pub const LayoutContext = BaseContext(void);
pub fn LayoutCtx(comptime DataType: type) type {
    return BaseContext(DataType);
}
pub const NotFoundContext = BaseContext(void);
pub fn NotFoundCtx(comptime DataType: type) type {
    return BaseContext(DataType);
}

pub const ErrorContext = struct {
    /// The HTTP request object (backend-agnostic)
    request: Request,
    /// The HTTP response object (backend-agnostic)
    response: Response,
    /// Global allocator
    allocator: std.mem.Allocator,
    /// Arena allocator for request-scoped allocations
    arena: std.mem.Allocator,
    /// The error that occurred
    err: anyerror,

    pub fn init(request: Request, response: Response, alloc: std.mem.Allocator, err: anyerror) ErrorContext {
        return .{
            .request = request,
            .response = response,
            .allocator = alloc,
            .arena = request.arena,
            .err = err,
        };
    }

    pub fn deinit(self: *ErrorContext) void {
        self.allocator.destroy(self);
    }
};

/// Socket options for configuring WebSocket behavior
pub const SocketOptions = struct {
    /// When true, publish() will also send the message to the sender.
    /// Default is false (sender is excluded from publish).
    publish_to_self: bool = false,
};

pub const Socket = struct {
    pub const VTable = struct {
        upgrade: *const fn (ctx: *anyopaque) anyerror!void,
        upgradeWithData: *const fn (ctx: *anyopaque, data: []const u8) anyerror!void,
        write: *const fn (ctx: *anyopaque, data: []const u8) anyerror!void,
        read: *const fn (ctx: *anyopaque) ?[]const u8,
        close: *const fn (ctx: *anyopaque) void,
        // Pub/Sub methods
        subscribe: *const fn (ctx: *anyopaque, topic: []const u8) void,
        unsubscribe: *const fn (ctx: *anyopaque, topic: []const u8) void,
        publish: *const fn (ctx: *anyopaque, topic: []const u8, message: []const u8) usize,
        isSubscribed: *const fn (ctx: *anyopaque, topic: []const u8) bool,
        // Options
        setPublishToSelf: *const fn (ctx: *anyopaque, value: bool) void,
    };

    backend_ctx: ?*anyopaque = null,
    vtable: ?*const VTable = null,

    pub fn upgrade(self: Socket, data: anytype) !void {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                const DataType = @TypeOf(data);
                if (DataType == void) {
                    try vt.upgrade(ctx);
                } else {
                    const data_bytes = std.mem.asBytes(&data);
                    try vt.upgradeWithData(ctx, data_bytes);
                }
            }
        }
    }

    /// Write data to the WebSocket connection.
    /// This should be called from the Socket handler to send messages.
    pub fn write(self: Socket, data: []const u8) !void {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                try vt.write(ctx, data);
            }
        }
    }

    pub fn read(self: Socket) ?[]const u8 {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                return vt.read(ctx);
            }
        }
        return null;
    }

    /// Close the WebSocket connection.
    pub fn close(self: Socket) void {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                vt.close(ctx);
            }
        }
    }

    /// Returns true if this socket has been upgraded to a WebSocket connection.
    pub fn isUpgraded(self: Socket) bool {
        return self.backend_ctx != null and self.vtable != null;
    }

    // =========================================================================
    // Pub/Sub API - Topic-based broadcasting
    // =========================================================================

    /// Subscribe to a topic to receive published messages.
    /// Multiple sockets can subscribe to the same topic.
    ///
    /// Example:
    /// ```zig
    /// ctx.socket.subscribe("chat-room");
    /// ctx.socket.subscribe("notifications");
    /// ```
    pub fn subscribe(self: Socket, topic: []const u8) void {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                vt.subscribe(ctx, topic);
            }
        }
    }

    /// Unsubscribe from a topic to stop receiving messages.
    ///
    /// Example:
    /// ```zig
    /// ctx.socket.unsubscribe("chat-room");
    /// ```
    pub fn unsubscribe(self: Socket, topic: []const u8) void {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                vt.unsubscribe(ctx, topic);
            }
        }
    }

    /// Publish a message to all subscribers of a topic, excluding the sender.
    /// Returns the number of sockets the message was sent to.
    ///
    /// Example:
    /// ```zig
    /// const sent = ctx.socket.publish("chat-room", "Hello everyone!");
    /// ```
    pub fn publish(self: Socket, topic: []const u8, message: []const u8) usize {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                return vt.publish(ctx, topic, message);
            }
        }
        return 0;
    }

    /// Check if this socket is subscribed to a topic.
    ///
    /// Example:
    /// ```zig
    /// if (ctx.socket.isSubscribed("chat-room")) {
    ///     // ...
    /// }
    /// ```
    pub fn isSubscribed(self: Socket, topic: []const u8) bool {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                return vt.isSubscribed(ctx, topic);
            }
        }
        return false;
    }

    /// Configure whether publish() sends to self.
    ///
    /// Example:
    /// ```zig
    /// ctx.socket.setPublishToSelf(true);
    /// // Now publish() will include the sender
    /// ```
    pub fn setPublishToSelf(self: Socket, value: bool) void {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                vt.setPublishToSelf(ctx, value);
            }
        }
    }

    /// Configure socket options.
    ///
    /// Example:
    /// ```zig
    /// ctx.socket.configure(.{ .publish_to_self = true });
    /// ```
    pub fn configure(self: Socket, options: SocketOptions) void {
        self.setPublishToSelf(options.publish_to_self);
    }
};

pub const RouteContext = struct {
    /// The HTTP request object (backend-agnostic)
    request: Request,
    /// The HTTP response object (backend-agnostic)
    response: Response,
    /// WebSocket interface for upgrading connections and sending/receiving messages
    socket: Socket,
    /// Global allocator
    allocator: std.mem.Allocator,
    /// Arena allocator for request-scoped allocations
    arena: std.mem.Allocator,

    pub fn init(request: Request, response: Response, alloc: std.mem.Allocator) RouteContext {
        return .{
            .request = request,
            .response = response,
            .socket = .{},
            .allocator = alloc,
            .arena = request.arena,
        };
    }

    pub fn initWithSocket(request: Request, response: Response, socket: Socket, alloc: std.mem.Allocator) RouteContext {
        return .{
            .request = request,
            .response = response,
            .socket = socket,
            .allocator = alloc,
            .arena = request.arena,
        };
    }

    pub fn fmt(self: RouteContext, comptime format: []const u8, args: anytype) ![]u8 {
        return fmtInner(self.arena, format, args);
    }
};

/// Message type for WebSocket messages (text vs binary)
pub const SocketMessageType = enum {
    text,
    binary,
};

/// Context for WebSocket message handlers (Socket function).
/// This is the primary handler called for each message received.
pub const SocketContext = SocketCtx(void);

/// Context for WebSocket handlers with custom data passed during upgrade.
/// Use SocketCtx(YourDataType) to access data passed via ctx.socket.upgrade(data).
pub fn SocketCtx(comptime DataType: type) type {
    return struct {
        /// The WebSocket connection for sending messages
        socket: Socket,
        /// The client message data (received from WebSocket)
        message: []const u8,
        /// The message type (text or binary)
        message_type: SocketMessageType,
        /// Custom data passed from upgrade handler
        data: DataType,
        /// Global allocator
        allocator: std.mem.Allocator,
        /// Arena allocator for request-scoped allocations
        arena: std.mem.Allocator,

        const Self = @This();

        pub fn fmt(self: Self, comptime format: []const u8, args: anytype) ![]u8 {
            return fmtInner(self.arena, format, args);
        }
    };
}

/// Context for SocketOpen handlers (called when connection opens).
/// Same structure as SocketCtx but without message data.
pub const SocketOpenContext = SocketOpenCtx(void);

pub fn SocketOpenCtx(comptime DataType: type) type {
    return struct {
        /// The WebSocket connection for sending messages
        socket: Socket,
        /// Custom data passed from upgrade handler
        data: DataType,
        /// Global allocator
        allocator: std.mem.Allocator,
        /// Arena allocator for request-scoped allocations
        arena: std.mem.Allocator,

        const Self = @This();

        pub fn fmt(self: Self, comptime format: []const u8, args: anytype) ![]u8 {
            return fmtInner(self.arena, format, args);
        }
    };
}

/// Context for SocketClose handlers (called when connection closes).
/// Same structure as SocketOpenCtx.
pub const SocketCloseContext = SocketCloseCtx(void);

pub fn SocketCloseCtx(comptime DataType: type) type {
    return struct {
        /// The WebSocket connection (may not be writable)
        socket: Socket,
        /// Custom data passed from upgrade handler
        data: DataType,
        /// Global allocator
        allocator: std.mem.Allocator,
        /// Arena allocator for request-scoped allocations
        arena: std.mem.Allocator,

        const Self = @This();

        pub fn fmt(self: Self, comptime format: []const u8, args: anytype) ![]u8 {
            return fmtInner(self.arena, format, args);
        }
    };
}

pub fn AppCtx(comptime DataType: type) type {
    return DataType;
}

fn fmtInner(allocator: std.mem.Allocator, comptime format: []const u8, args: anytype) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    aw.writer.print(format, args) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
    };
    return aw.toOwnedSlice();
}
