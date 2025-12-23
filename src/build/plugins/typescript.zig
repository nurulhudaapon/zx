// TODO: Plugin should always be a file with main() function that receiveds standaridized args
// Maybe there can be stdio mode where files will be provided in zon format line by line
pub fn typescript(b: *std.Build, options: ReactPluginOptions) ZxInitOptions.PluginOptions {
    _ = options;

    // TODO: paths from args
    const cmd: *std.Build.Step.Run = .create(b, "typescript");
    cmd.addFileArg(b.path("site/node_modules/.bin/esbuild"));
    cmd.addFileArg(b.path("site/main.ts"));
    cmd.addArgs(&.{ "--bundle", "--log-level=silent" });
    cmd.addPrefixedFileArg("--outfile=", b.path("site/.zx/assets/main.js"));

    if (builtin.mode != .Debug) {
        cmd.addArgs(&.{
            "--minify",
            "--define:__DEV__=false",
            "--define:process.env.NODE_ENV=\"production\"",
        });
    } else {
        cmd.addArgs(&.{
            "--sourcemap=inline",
            "--define:__DEV__=true",
            "--define:process.env.NODE_ENV=\"development\"",
        });
    }

    return .{
        .name = "typescript",
        .steps = &.{
            // .{
            //     .command = .{
            //         .type = .after_transpile,
            //         .args = &.{
            //             "bun",
            //             "install",
            //         },
            //     },
            // },
            .{
                .command = .{
                    .type = .after_transpile,
                    .run = cmd,
                },
            },
        },
    };
}

const std = @import("std");
const builtin = @import("builtin");

const ReactPluginOptions = struct {};

const ZxInitOptions = @import("../init/ZxInitOptions.zig");
