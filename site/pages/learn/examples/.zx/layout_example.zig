pub fn Layout(ctx: zx.LayoutContext, children: zx.Component) zx.Component {
    var _zx = zx.initWithAllocator(ctx.arena);
    return _zx.zx(
        .html,
        .{
            .allocator = ctx.arena,
            .children = &.{
                _zx.zx(
                    .head,
                    .{
                        .children = &.{
                            _zx.zx(
                                .title,
                                .{
                                    .children = &.{
                                        _zx.txt("My App"),
                                    },
                                },
                            ),
                        },
                    },
                ),
                _zx.zx(
                    .body,
                    .{
                        .children = &.{
                            _zx.zx(
                                .nav,
                                .{
                                    .children = &.{
                                        _zx.zx(
                                            .a,
                                            .{
                                                .attributes = &.{
                                                    .{ .name = "href", .value = "/" },
                                                },
                                                .children = &.{
                                                    _zx.txt("Home"),
                                                },
                                            },
                                        ),
                                        _zx.zx(
                                            .a,
                                            .{
                                                .attributes = &.{
                                                    .{ .name = "href", .value = "/about" },
                                                },
                                                .children = &.{
                                                    _zx.txt("About"),
                                                },
                                            },
                                        ),
                                    },
                                },
                            ),
                            _zx.zx(
                                .main,
                                .{
                                    .children = &.{
                                        _zx.txt(children),
                                    },
                                },
                            ),
                            _zx.zx(
                                .footer,
                                .{
                                    .children = &.{
                                        _zx.txt("© 2025 My App"),
                                    },
                                },
                            ),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
