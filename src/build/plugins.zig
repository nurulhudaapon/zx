//! Plugins are experimental and will change in the future
//! // TODO: Plugin should always be a file with main() function that receiveds standaridized args
// Maybe there can be stdio mode where files will be provided in zon format line by line
pub const tailwind = @import("plugins/tailwind.zig").tailwind;
pub const esbuild = @import("plugins/esbuild.zig").esbuild;
