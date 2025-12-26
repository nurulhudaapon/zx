### 📟 zli - a blazing-fast CLI framework for Zig.

Build modular, ergonomic, and high-performance CLIs with ease.

Batteries included. [ZLI reference docs](https://xcaeser.github.io/zli)

[![Tests](https://github.com/xcaeser/zli/actions/workflows/main.yml/badge.svg)](https://github.com/xcaeser/zli/actions/workflows/main.yml)
[![Zig Version](https://img.shields.io/badge/Zig_Version-0.15.2-orange.svg?logo=zig)](README.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg?logo=cachet)](LICENSE)
[![Built by xcaeser](https://img.shields.io/badge/Built%20by-@xcaeser-blue)](https://github.com/xcaeser)
[![Version](https://img.shields.io/badge/ZLI-v4.3.0-green)](https://github.com/xcaeser/zli/releases)

## 🚀 Features

- Modular commands & subcommands
- Fast flag parsing (`--flag`, `--flag=value`, shorthand `-abc`)
- Type-safe support for `bool`, `int`, `string`
- Named positional arguments with `required`, `optional`, `variadic`
- Auto help/version/deprecation handling
- Pretty help output with aligned flags & args
- Spinners for a more interactive experience
- Usage hints, context-aware

## 📦 Installation

```sh
zig fetch --save=zli https://github.com/xcaeser/zli/archive/v4.3.0.tar.gz
```

Add to your `build.zig`:

```zig
const zli_dep = b.dependency("zli", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("zli", zli_dep.module("zli"));
```

## 🗂 Recommended Structure (but you can do what you want)

```
your-app/
├── build.zig
├── src/
│   ├── main.zig
│   └── cli/
│       ├── root.zig // zli entrypoint
│       ├── run.zig  // subcommand 1
│       └── version.zig // subcommand 1
        ... // subcommand of subcommands, go nuts
```

- Each command is in its own file
- You explicitly register subcommands
- `root.zig` is the entry point

## 🧪 Example

### Your program

```zig
// src/main.zig
const std = @import("std");
const fs = std.fs;
const cli = @import("cli/root.zig");

pub fn main() !void {
    var dbg = std.heap.DebugAllocator(.{}).init;

    const allocator = switch (@import("builtin").mode) {
        .Debug => dbg.allocator(),
        .ReleaseFast, .ReleaseSafe, .ReleaseSmall => std.heap.smp_allocator,
    };

    defer if (@import("builtin").mode == .Debug) std.debug.assert(dbg.deinit() == .ok);

    var stdout_writer = fs.File.stdout().writerStreaming(&.{});
    var stdout = &stdout_writer.interface;

    var buf: [4096]u8 = undefined;
    var stdin_reader = fs.File.stdin().readerStreaming(&buf);
    const stdin = &stdin_reader.interface;

    const root = try cli.build(stdout, stdin, allocator);
    defer root.deinit();

    try root.execute(.{}); // Or pass data with: try root.execute(.{ .data = &my_data });

    try stdout_writer.flush(); // Don't forget to flush!
}
```

### Root command - entrypoint

```zig
// src/cli/root.zig
const std = @import("std");
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;
const zli = @import("zli");

const run = @import("run.zig");
const version = @import("version.zig");

pub fn build(writer: *Writer, reader: *Reader, allocator: std.mem.Allocator) !*zli.Command {
    const root = try zli.Command.init(writer, reader, allocator, .{
        .name = "blitz",
        .description = "Your dev toolkit CLI",
        .version = .{ .major = 0, .minor = 0, .patch = 1, .pre = null, .build = null },
    }, showHelp);

    try root.addCommands(&.{
        try run.register(writer, reader, allocator),
        try version.register(writer, reader, allocator),
    });

    return root;
}

fn showHelp(ctx: zli.CommandContext) !void {
    try ctx.command.printHelp();
}
```

### Run subcommand

```zig
// src/cli/run.zig
const std = @import("std");
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;
const zli = @import("zli");

const now_flag = zli.Flag{
    .name = "now",
    .shortcut = "n",
    .description = "Run immediately",
    .type = .Bool,
    .default_value = .{ .Bool = false },
};

pub fn register(writer: *Writer, reader: *Reader, allocator: std.mem.Allocator) !*zli.Command {
    const cmd = try zli.Command.init(writer, reader, allocator, .{
        .name = "run",
        .description = "Run your workflow",
    }, run);

    try cmd.addFlag(now_flag);
    try cmd.addPositionalArg(.{
        .name = "script",
        .description = "Script to execute",
        .required = true,
    });
    try cmd.addPositionalArg(.{
        .name = "env",
        .description = "Environment name",
        .required = false,
    });

    return cmd;
}

fn run(ctx: zli.CommandContext) !void {
    const now = ctx.flag("now", bool); // type-safe flag access

    const script = ctx.getArg("script") orelse {
        try ctx.writer.print("Missing script arg\n", .{});
        return;
    };
    const env = ctx.getArg("env") orelse "default";

    std.debug.print("Running {s} in {s} (now = {})\n", .{ script, env, now });

    // You can also get other commands by name:
    // if (ctx.root.findCommand("create")) |create_cmd| {
    //    try create_cmd.printUsageLine();
    // }

    // if you passed data to your root command, you can access it here:
    // const object = ctx.getContextData(type_of_your_data); // can be struct, []const u8, etc., object is a pointer.

};
```

### Version subcommand

```zig
// src/cli/version.zig
const std = @import("std");
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;
const zli = @import("zli");

pub fn register(writer: *Writer, reader: *Reader, allocator: std.mem.Allocator) !*zli.Command {
    return zli.Command.init(writer, reader, allocator, .{
        .name = "version",
        .shortcut = "v",
        .description = "Show CLI version",
    }, show);
}

fn show(ctx: zli.CommandContext) !void {
    try ctx.root.printVersion();
}
```

### Spinners example

Available funtions:

- `spinner.start`: to add a new line. sets the spinner to running
- `spinner.updateStyle`: to update the spinner style
- `spinner.updateMessage`: to update text of a running spinner
- `spinner.succeed`, `fail`, `info`, `preserve`: mandatory to complete a line you started. each `spinner.start` needs a `spinner.succeed`, `fail` etc.. spinner after this action is done for that specific line
- Recommendation: use `spinner.print` instead of your own `writer.print` to not have non-displayed messages as spinner works on its own thread

```zig
const std = @import("std");
const zli = @import("zli");

pub fn run(ctx: zli.CommandContext) !void {
    var spinner = ctx.spinner;
    spinner.updateStyle(.{ .frames = Spinner.SpinnerStyles.earth, .refresh_rate_ms = 150 }); // many styles available

    // Step 1
    try spinner.start("Step 1", .{}); // New line
    std.Thread.sleep(2000 * std.time.ns_per_ms);

    try spinner.succeed("Step 1 success", .{}); // each start must be closed with succeed, fail, info, preserve

    spinner.updateStyle(.{ .frames = Spinner.SpinnerStyles.weather, .refresh_rate_ms = 150 }); // many styles available

    // Step 2
    try spinner.start("Step 2", .{}); // New line
    std.Thread.sleep(3000 * std.time.ns_per_ms);

    spinner.updateStyle(.{ .frames = Spinner.SpinnerStyles.dots, .refresh_rate_ms = 150 }); // many styles available
    try spinner.updateMessage("Step 2: Calculating things...", .{}); // update the text of step 2

    const i = work(); // do some work

    try spinner.info("Step 2 info: {d}", .{i});

    // Step 3
    try spinner.start("Step 3", .{});
    std.Thread.sleep(2000 * std.time.ns_per_ms);

    try spinner.fail("Step 3 fail", .{});

    try spinner.print("Finish\n", .{}); // instead of using ctx.writer or another writer to avoid concurrency issues
}

fn work() u128 {
    var i: u128 = 1;
    for (0..100000000) |t| {
        i = (t + i);
    }

    return i;
}
```

## ✅ Features Checklist

- [x] Commands & subcommands
- [x] Command aliases
- [x] Flags & shorthands
- [x] Type-safe flag values
- [x] Positional args (required, optional, variadic)
- [x] Named access: `ctx.getArg("name")`
- [x] Context data
- [x] Help/version auto handling
- [x] Deprecation notices
- [x] Pretty-aligned help for flags & args
- [x] Clean usage output like Cobra
- [x] Spinners and loading state (very powerful)
- [ ] Persistent flags

## 📚 Documentation

See [docs](https://xcaeser.github.io/zli/) for full usage, examples, and internals.

## 📝 License

MIT. See [LICENSE](LICENSE). Contributions welcome.
