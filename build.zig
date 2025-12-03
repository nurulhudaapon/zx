const build_zon = @import("build.zig.zon");
const std = @import("std");

const buildlib = @import("src/build/main.zig");

// --- Public API (setting up ZX Site) --- //
/// Deprecated in favor of `zx.init(b, exe, options)`
pub const setup = buildlib.setup;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- ZX Meta Options --- //
    const options = b.addOptions();
    options.addOption([]const u8, "version_string", build_zon.version);
    options.addOption([]const u8, "description", build_zon.description);
    options.addOption([]const u8, "repository", build_zon.repository);

    // --- ZX App Module --- //
    const mod = b.addModule("zx", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const httpz_dep = b.dependency("httpz", .{ .target = target, .optimize = optimize });
    mod.addImport("httpz", httpz_dep.module("httpz"));
    mod.addOptions("zx_info", options);

    // --- ZX WASM Module --- //
    const zx_wasm_mod = b.addModule("zx_wasm", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const jsz_dep = b.dependency("zig_js", .{ .target = target, .optimize = optimize });
    zx_wasm_mod.addImport("js", jsz_dep.module("zig-js"));
    zx_wasm_mod.addOptions("zx_info", options);

    // --- ZX CLI (Transpiler, Exporter, Dev Server) --- //
    // const rustlib_step = buildlib.rustlib.build(b, target, optimize);
    const zli_dep = b.dependency("zli", .{ .target = target, .optimize = optimize });
    const exe = b.addExecutable(.{
        .name = "zx",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zx", .module = mod },
                .{ .name = "zli", .module = zli_dep.module("zli") },
            },
        }),
    });
    // buildlib.rustlib.link(b, exe, rustlib_step, optimize);
    b.installArtifact(exe);

    // --- Steps: Run --- //
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    // --- ZX Site (Docs, Example, sample) --- //
    {
        const is_zx_docsite = b.option(bool, "zx-docsite", "Build the ZX docsite") orelse false;

        if (is_zx_docsite) {
            const zx_docsite_exe = b.addExecutable(.{
                .name = "zx_site",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("site/main.zig"),
                    .target = target,
                    .optimize = optimize,
                }),
            });

            initInner(b, zx_docsite_exe, exe, mod, zx_wasm_mod, .{
                .cli_path = null,
                .site_outdir = "site/.zx",
                .site_path = "site",
            }) catch unreachable;
        }
    }

    // --- Steps: Test --- //
    {
        const mod_tests = b.addTest(.{ .root_module = mod });
        const run_mod_tests = b.addRunArtifact(mod_tests);

        const exe_tests = b.addTest(.{ .root_module = exe.root_module });
        const run_exe_tests = b.addRunArtifact(exe_tests);

        const testing_mod = b.createModule(.{
            .root_source_file = b.path("test/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zx", .module = mod },
            },
        });
        const testing_mod_tests = b.addTest(.{
            .root_module = testing_mod,
            .test_runner = .{ .path = b.path("test/runner.zig"), .mode = .simple },
        });
        const run_transpiler_tests = b.addRunArtifact(testing_mod_tests);

        const test_step = b.step("test", "Run tests");
        test_step.dependOn(&run_mod_tests.step);
        test_step.dependOn(&run_exe_tests.step);
        test_step.dependOn(&run_transpiler_tests.step);
    }

    // --- ZX Releases (Cross-compilation targets for all platforms) --- //
    {
        const release_targets = [_]struct {
            name: []const u8,
            target: std.Target.Query,
        }{
            .{ .name = "linux-x64", .target = .{ .cpu_arch = .x86_64, .os_tag = .linux } },
            .{ .name = "linux-aarch64", .target = .{ .cpu_arch = .aarch64, .os_tag = .linux } },
            .{ .name = "macos-x64", .target = .{ .cpu_arch = .x86_64, .os_tag = .macos } },
            .{ .name = "macos-aarch64", .target = .{ .cpu_arch = .aarch64, .os_tag = .macos } },
            .{ .name = "windows-x64", .target = .{ .cpu_arch = .x86_64, .os_tag = .windows } },
            .{ .name = "windows-aarch64", .target = .{ .cpu_arch = .aarch64, .os_tag = .windows } },
        };

        const release_step = b.step("release", "Build release binaries for all targets");

        for (release_targets) |release_target| {
            const resolved_target = b.resolveTargetQuery(release_target.target);
            const release_exe = b.addExecutable(.{
                .name = "zx",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("src/main.zig"),
                    .target = resolved_target,
                    .optimize = .ReleaseFast,
                    .imports = &.{
                        .{ .name = "zx", .module = mod },
                        .{ .name = "httpz", .module = httpz_dep.module("httpz") },
                        .{ .name = "zli", .module = zli_dep.module("zli") },
                    },
                }),
            });

            // const release_rustlib_step = buildlib.rustlib.build(b, resolved_target, .ReleaseFast);
            // buildlib.rustlib.link(b, release_exe, release_rustlib_step, .ReleaseFast);

            const exe_ext = if (resolved_target.result.os.tag == .windows) ".exe" else "";
            const install_release = b.addInstallArtifact(release_exe, .{
                .dest_sub_path = b.fmt("release/zx-{s}{s}", .{ release_target.name, exe_ext }),
            });

            const target_step = b.step(
                b.fmt("release-{s}", .{release_target.name}),
                b.fmt("Build release binary for {s}", .{release_target.name}),
            );
            target_step.dependOn(&install_release.step);
            release_step.dependOn(&install_release.step);
        }
    }
}

/// Options for initializing a ZX project
pub const ZxInitOptions = struct {
    const CliOptions = struct {
        /// Path to the ZX CLI executable, if null then the ZX CLI will be used from system path (`zx`)
        path: ?[]const u8 = null,
    };

    const SiteOptions = struct {
        /// Path to the ZX site, by default it is `site`
        path: []const u8,
    };

    // It is recommended to use the default options, but you can override them if you want to
    site: ?SiteOptions = null,

    /// Options for the ZX CLI, if null then the ZX CLI will be used from the soure of ZX dependency
    cli: ?CliOptions = null,
};

const default_inner_opts: InitInnerOptions = .{
    .site_path = "site",
    .cli_path = "zx",
    .site_outdir = null,
};

pub fn init(b: *std.Build, exe: *std.Build.Step.Compile, options: ZxInitOptions) !void {
    const target = exe.root_module.resolved_target;
    const optimize = exe.root_module.optimize;
    const zx_dep = b.dependencyFromBuildZig(@This(), .{ .target = target, .optimize = optimize });

    const zx_module = zx_dep.module("zx");
    const zx_wasm_module = zx_dep.module("zx_wasm");
    const zx_exe = zx_dep.artifact("zx");

    var opts = default_inner_opts;

    if (options.site) |site_opts| {
        opts.site_path = site_opts.path;
    }

    if (options.cli) |cli_opts| {
        opts.cli_path = cli_opts.path;
    }

    return initInner(b, exe, zx_exe, zx_module, zx_wasm_module, opts);
}

const InitInnerOptions = struct {
    site_path: []const u8,
    cli_path: ?[]const u8,
    site_outdir: ?[]const u8 = null,
};

fn initInner(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    zx_exe: *std.Build.Step.Compile,
    zx_module: *std.Build.Module,
    zx_wasm_module: *std.Build.Module,
    opts: InitInnerOptions,
) !void {
    // const target = exe.root_module.resolved_target;
    const optimize = exe.root_module.optimize;

    // --- ZX Transpilation ---
    const site_root_path = opts.site_path;
    const transpile_cmd = transpile_blk: {
        if (opts.cli_path != null)
            break :transpile_blk b.addSystemCommand(&.{opts.cli_path.?});

        break :transpile_blk b.addRunArtifact(zx_exe);
    };

    transpile_cmd.addArgs(&.{ "transpile", b.pathJoin(&.{site_root_path}), "--outdir" });
    const outdir = outdir_blk: {
        if (opts.site_outdir != null) {
            transpile_cmd.addArg(opts.site_outdir.?);
            break :outdir_blk b.path(opts.site_outdir.?);
        } else {
            break :outdir_blk transpile_cmd.addOutputDirectoryArg(site_root_path);
        }
    };

    transpile_cmd.expectExitCode(0);

    // --- ZX File Cache Invalidator ---
    const site_path = b.path(site_root_path).getPath3(b, &transpile_cmd.step);
    var site_dir = try site_path.root_dir.handle.openDir(site_path.subPathOrDot(), .{ .iterate = true });
    var itd = try site_dir.walk(transpile_cmd.step.owner.allocator);
    defer itd.deinit();
    while (itd.next() catch @panic("OOM")) |entry| {
        switch (entry.kind) {
            .directory => {},
            .file => {
                const entry_path = try site_path.join(transpile_cmd.step.owner.allocator, entry.path);
                transpile_cmd.addFileInput(b.path(entry_path.sub_path));
            },
            else => continue,
        }
    }

    // --- ZX Site Main Executable ---
    exe.root_module.addImport("zx", zx_module);

    var imports = std.array_list.Managed(std.Build.Module.Import).init(b.allocator);
    var import_it = exe.root_module.import_table.iterator();
    while (import_it.next()) |entry| {
        try imports.append(.{ .name = entry.key_ptr.*, .module = entry.value_ptr.* });
    }

    exe.root_module.addAnonymousImport("zx_meta", .{
        .root_source_file = outdir.path(b, "meta.zig"),
        .imports = imports.items,
    });

    exe.step.dependOn(&transpile_cmd.step);
    b.installArtifact(exe);

    // --- ZX WASM Main Executable ---
    const wasm_exe = b.addExecutable(.{
        .name = "zx_wasm",
        .root_module = b.createModule(.{
            .root_source_file = exe.root_module.root_source_file,
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding, .abi = .none }),
            .optimize = optimize,
        }),
    });
    wasm_exe.root_module.addImport("zx", zx_wasm_module);
    wasm_exe.entry = .disabled;
    wasm_exe.export_memory = true;
    wasm_exe.rdynamic = true;

    const wasm_install = b.addInstallFileWithDir(
        wasm_exe.getEmittedBin(),
        .{ .custom = b.pathJoin(&.{ "..", site_root_path, "assets" }) },
        "main.wasm",
    );

    wasm_exe.root_module.addAnonymousImport("zx_components", .{
        .root_source_file = outdir.path(b, "components.zig"),
        .imports = &.{
            .{ .name = "zx", .module = zx_wasm_module },
        },
    });

    b.default_step.dependOn(&wasm_install.step);
    wasm_exe.step.dependOn(&transpile_cmd.step);
    b.installArtifact(wasm_exe);

    // --- Steps: Serve ---
    const serve_step = b.step("serve", "Run the Zx website");
    const serve_cmd = b.addRunArtifact(exe);
    serve_cmd.step.dependOn(&transpile_cmd.step);
    serve_cmd.step.dependOn(b.getInstallStep());
    serve_step.dependOn(&serve_cmd.step);
    if (b.args) |args| serve_cmd.addArgs(args);
}
