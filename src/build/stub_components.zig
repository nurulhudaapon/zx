//! Stub components module for standalone library builds.
//! This provides an empty components array when zx is built without CSR enabled.
const zx = @import("zx");

pub const components: []const zx.Client.ComponentMeta = &.{};
