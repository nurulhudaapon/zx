//! The Request interface of the Fetch API represents a resource request.
//!
//! You can create a new Request object using the Request.Builder, but you are more likely
//! to encounter a Request object being returned as part of another API operation, such as
//! a page handler context receiving an incoming HTTP request.
//!
//! This module is backend-agnostic. The actual implementation is provided via vtable.
//!
//! https://developer.mozilla.org/en-US/docs/Web/API/Request

const std = @import("std");
const common = @import("common.zig");

pub const Request = @This();

// Re-export common types for convenience
pub const Method = common.Method;
pub const Version = common.Version;
pub const Protocol = common.Protocol; // Deprecated alias for Version
pub const Cookies = common.Cookies;
pub const Header = common.Header;
/// @deprecated Use `Header` instead.
pub const Entry = Header;
pub const MultiFormEntry = common.MultiFormEntry;

// --- Instance Properties --- //
// https://developer.mozilla.org/en-US/docs/Web/API/Request#instance_properties

/// Contains the URL of the request.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/Request/url
url: []const u8,

/// Contains the request's method (GET, POST, etc.).
///
/// https://developer.mozilla.org/en-US/docs/Web/API/Request/method
///
/// **Zig Note:** In the web standard, this is a string. In this implementation,
/// it is represented as a `Method` enum for type safety. The original string
/// is available via `method_str`.
method: Method,

/// Contains the request's method as a string.
///
/// **Zig Note:** This is an extension field. In the web standard, `method` is
/// already a string. This field preserves the original string representation.
method_str: []const u8 = "",

/// Contains the pathname portion of the URL.
///
/// **Zig Note:** This is an extension field not present in the web standard Request.
/// In the web standard, you would parse the URL to get the pathname.
/// Example: https://foo.com/bar/baz -> /bar/baz
pathname: []const u8,

/// Contains the referrer of the request (e.g., client, no-referrer, or a URL).
///
/// https://developer.mozilla.org/en-US/docs/Web/API/Request/referrer
///
/// **Zig Note:** In the web standard, this defaults to "about:client". In this
/// implementation, it defaults to an empty string.
referrer: []const u8 = "",

/// Contains the search/query string portion of the URL.
///
/// **Zig Note:** This is an extension field not present in the web standard Request.
/// In the web standard, you would parse the URL to get the search string.
/// Example: https://foo.com/bar?q=qux -> q=qux
search: []const u8 = "",

/// Contains the associated Headers object of the request.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/Request/headers
headers: Headers,

/// Cookie accessor for parsing cookies from the Cookie header.
///
/// **Zig Note:** This is an extension field not present in the web standard Request.
/// In the web standard, you would access cookies via `document.cookie` or parse
/// the Cookie header manually.
cookies: Cookies = .{ .header_value = "" },

/// URL search parameters accessor.
///
/// **Zig Note:** This is an extension field. In the web standard, you would use
/// `new URL(request.url).searchParams` to access search parameters.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams
searchParams: URLSearchParams = .{},

/// HTTP protocol version (HTTP/1.0 or HTTP/1.1).
///
/// **Zig Note:** This is an extension field not present in the web standard Request.
/// The web standard Request doesn't expose the HTTP protocol version.
/// Uses `std.http.Version` from the standard library.
protocol: Version = .@"HTTP/1.1",

// --- Internal Fields (not part of web standard) --- //

/// Arena allocator for request-scoped allocations.
///
/// **Zig Note:** This is an internal field not present in the web standard.
/// Used for memory management in the Zig implementation.
arena: std.mem.Allocator,

/// Backend-specific context pointer (null for WASM/client-side).
///
/// **Zig Note:** This is an internal field not present in the web standard.
/// Provides the vtable pattern for backend abstraction.
backend_ctx: ?*anyopaque = null,

/// VTable for backend-specific operations.
///
/// **Zig Note:** This is an internal field not present in the web standard.
/// Allows different HTTP server backends to implement request operations.
vtable: ?*const VTable = null,

/// VTable interface for backend-specific request operations.
///
/// **Zig Note:** This is an internal type not present in the web standard.
pub const VTable = struct {
    /// Returns the request body as text.
    text: *const fn (ctx: *anyopaque) ?[]const u8 = &defaultText,
    /// Returns a URL parameter by name (from route matching).
    getParam: *const fn (ctx: *anyopaque, name: []const u8) ?[]const u8 = &defaultGetParam,

    fn defaultText(_: *anyopaque) ?[]const u8 {
        return null;
    }
    fn defaultGetParam(_: *anyopaque, _: []const u8) ?[]const u8 {
        return null;
    }
};

// --- Instance Methods --- //
// https://developer.mozilla.org/en-US/docs/Web/API/Request#instance_methods

/// Returns a promise that resolves with a text representation of the request body.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/Request/text
///
/// **Zig Note:** In the web standard, this returns a Promise<string>. In this
/// implementation, it returns `?[]const u8` synchronously (null if no body).
pub fn text(self: *const Request) ?[]const u8 {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.text(ctx);
        }
    }
    return null;
}

/// Returns a URL parameter by name (from route matching).
///
/// **Zig Note:** This is an extension method not present in the web standard Request.
/// Used for accessing dynamic route parameters (e.g., /users/:id -> getParam("id")).
pub fn getParam(self: *const Request, name: []const u8) ?[]const u8 {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.getParam(ctx, name);
        }
    }
    return null;
}

// --- URLSearchParams --- //
// https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams

/// The URLSearchParams interface defines utility methods to work with the
/// query string of a URL.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams
///
/// **Zig Note:** This is a simplified implementation that delegates to the backend.
/// Not all methods from the web standard URLSearchParams interface are implemented.
pub const URLSearchParams = struct {
    backend_ctx: ?*anyopaque = null,
    vtable: ?*const URLSearchParamsVTable = null,

    pub const URLSearchParamsVTable = struct {
        get: *const fn (ctx: *anyopaque, name: []const u8) ?[]const u8,
        has: *const fn (ctx: *anyopaque, name: []const u8) bool,
    };

    /// Returns the first value associated with the given search parameter.
    ///
    /// https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams/get
    ///
    /// **Zig Note:** Returns `?[]const u8` instead of `string | null`.
    pub fn get(self: *const URLSearchParams, name: []const u8) ?[]const u8 {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                return vt.get(ctx, name);
            }
        }
        return null;
    }

    /// Returns a boolean indicating if such a given parameter exists.
    ///
    /// https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams/has
    pub fn has(self: *const URLSearchParams, name: []const u8) bool {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                return vt.has(ctx, name);
            }
        }
        return false;
    }
};

// --- Headers --- //
// https://developer.mozilla.org/en-US/docs/Web/API/Headers

/// The Headers interface of the Fetch API allows you to perform various actions
/// on HTTP request and response headers.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/Headers
///
/// **Zig Note:** This is a simplified read-only implementation for request headers.
/// Not all methods from the web standard Headers interface are implemented.
pub const Headers = struct {
    backend_ctx: ?*anyopaque = null,
    vtable: ?*const HeadersVTable = null,

    pub const HeadersVTable = struct {
        get: *const fn (ctx: *anyopaque, name: []const u8) ?[]const u8,
        has: *const fn (ctx: *anyopaque, name: []const u8) bool,
    };

    /// Returns a String sequence of all the values of a header within a Headers
    /// object with a given name.
    ///
    /// https://developer.mozilla.org/en-US/docs/Web/API/Headers/get
    ///
    /// **Zig Note:** Returns `?[]const u8` instead of a string, returning `null`
    /// if the header is not found.
    pub fn get(self: *const Headers, name: []const u8) ?[]const u8 {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                return vt.get(ctx, name);
            }
        }
        return null;
    }

    /// Returns a boolean stating whether a Headers object contains a certain header.
    ///
    /// https://developer.mozilla.org/en-US/docs/Web/API/Headers/has
    pub fn has(self: *const Headers, name: []const u8) bool {
        if (self.vtable) |vt| {
            if (self.backend_ctx) |ctx| {
                return vt.has(ctx, name);
            }
        }
        return false;
    }
};

// --- Builder (not part of web standard) --- //

/// Builder for creating Request objects.
///
/// **Zig Note:** This is an internal type not present in the web standard.
/// In the web standard, you would use the `new Request(input, init)` constructor.
/// This builder pattern is used for backend implementations to construct
/// Request objects with the appropriate vtable and context.
pub const Builder = struct {
    url: []const u8 = "",
    method: Method = .GET,
    method_str: []const u8 = "GET",
    pathname: []const u8 = "/",
    referrer: []const u8 = "",
    search: []const u8 = "",
    protocol: Version = .@"HTTP/1.1",
    arena: std.mem.Allocator,
    backend_ctx: ?*anyopaque = null,
    vtable: ?*const VTable = null,
    headers_ctx: ?*anyopaque = null,
    headers_vtable: ?*const Headers.HeadersVTable = null,
    cookie_header: []const u8 = "",
    search_params_ctx: ?*anyopaque = null,
    search_params_vtable: ?*const URLSearchParams.URLSearchParamsVTable = null,

    /// Builds the Request object with all configured values.
    pub fn build(self: Builder) Request {
        return .{
            .url = self.url,
            .method = self.method,
            .method_str = self.method_str,
            .pathname = self.pathname,
            .referrer = self.referrer,
            .search = self.search,
            .protocol = self.protocol,
            .arena = self.arena,
            .backend_ctx = self.backend_ctx,
            .vtable = self.vtable,
            .headers = .{
                .backend_ctx = self.headers_ctx,
                .vtable = self.headers_vtable,
            },
            .cookies = .{ .header_value = self.cookie_header },
            .searchParams = .{
                .backend_ctx = self.search_params_ctx,
                .vtable = self.search_params_vtable,
            },
        };
    }
};
