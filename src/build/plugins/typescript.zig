// TODO: Plugin should always be a file with main() function that receiveds standaridized args
// Maybe there can be stdio mode where files will be provided in zon format line by line
pub fn typescript(options: ReactPluginOptions) ZxInitOptions.PluginOptions {
    _ = options;

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
                    .args = &.{
                        "site/node_modules/.bin/esbuild",
                        "site/main.ts",
                        "--bundle",
                        "--minify",
                        "--define:process.env.NODE_ENV=\"production\"",
                        "--define:__DEV__=false",
                        "--outfile=site/.zx/assets/main.js",
                        "--log-level=silent",
                    },
                },
            },
        },
    };
}

const ReactPluginOptions = struct {};

const ZxInitOptions = @import("../init/ZxInitOptions.zig");
