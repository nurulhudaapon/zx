const std = @import("std");
const zx = @import("zx");

pub fn build(b: *std.Build) !void {
    const exe = b.addExecutable(.{ .name = "my-site" });

    try zx.init(b, exe, .{
        .plugins = &.{
            zx.plugins.esbuild(b, .{
                .input = b.path("site/main.ts"),
                .output = b.path("{outdir}/assets/main.js"),
            }),
        },
    });
}
