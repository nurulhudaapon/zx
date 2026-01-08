//! Routing contexts for page, layout, error, and not-found handlers.
//! This module is backend-agnostic - no httpz dependency.

const std = @import("std");
const Request = @import("Request.zig");
const Response = @import("Response.zig");

/// Base context structure that provides access to request/response objects and allocators.
/// This is the foundation for both PageContext and LayoutContext, providing common functionality
/// for handling HTTP requests and managing memory allocation.
pub const BaseContext = struct {
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
    parent_ctx: ?*BaseContext = null,

    /// Initialize a new BaseContext with the given request, response, and allocator.
    pub fn init(request: Request, response: Response, alloc: std.mem.Allocator) BaseContext {
        return .{
            .request = request,
            .response = response,
            .allocator = alloc,
            .arena = request.arena,
        };
    }

    /// Deinitialize the context, freeing any resources allocated with the global allocator.
    /// Note: The arena allocator is automatically cleaned up by the request handler.
    pub fn deinit(self: *BaseContext) void {
        self.allocator.destroy(self);
    }
};

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
pub const PageContext = BaseContext;

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
pub const LayoutContext = BaseContext;
pub const NotFoundContext = BaseContext;

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

pub const RouteContext = struct {
    /// The HTTP request object (backend-agnostic)
    request: Request,
    /// The HTTP response object (backend-agnostic)
    response: Response,
    /// Global allocator
    allocator: std.mem.Allocator,
    /// Arena allocator for request-scoped allocations
    arena: std.mem.Allocator,

    pub fn init(request: Request, response: Response, alloc: std.mem.Allocator) RouteContext {
        return .{
            .request = request,
            .response = response,
            .allocator = alloc,
            .arena = request.arena,
        };
    }
};
