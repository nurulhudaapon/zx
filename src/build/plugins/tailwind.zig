pub fn tailwind(b: *std.Build, options: TailwindPluginOptions) ZxInitOptions.PluginOptions {
    const bin = options.bin orelse b.path("site/node_modules/.bin/tailwindcss");
    const input = options.input orelse b.path("site/styles.css");
    const output = options.output orelse b.path("{outdir}/assets/styles.css");

    const cmd: *std.Build.Step.Run = .create(b, "tailwind");
    cmd.addFileArg(bin);
    cmd.addArg("--map");
    cmd.addPrefixedFileArg("-i ", input);
    cmd.addPrefixedFileArg("-o ", output);

    const steps = b.allocator.alloc(ZxInitOptions.PluginOptions.PluginStep, 1) catch @panic("OOM");
    steps[0] = .{
        .command = .{
            .type = .after_transpile,
            .run = cmd,
        },
    };

    return .{
        .name = "tailwindcss",
        .steps = steps,
    };
}

const std = @import("std");
const LazyPath = std.Build.LazyPath;

const TailwindPluginOptions = struct {
    bin: ?LazyPath = null,
    input: ?LazyPath = null,
    output: ?LazyPath = null,
};

const ZxInitOptions = @import("../init/ZxInitOptions.zig");
