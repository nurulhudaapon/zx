//! Stub meta module for standalone library builds.
//! This provides an empty routes array when zx is built without a user project.
const zx = @import("zx");

pub const routes: []const zx.App.Meta.Route = &.{};

pub const meta = zx.App.Meta{
    .routes = &routes,
    .rootdir = "",
};

/// Re-export components (stub for standalone builds)
pub const components = @import("stub_components.zig");
