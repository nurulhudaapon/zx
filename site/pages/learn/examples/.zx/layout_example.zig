pub fn Layout(ctx: zx.LayoutContext, children: zx.Component) zx.Component {
    var _zx = zx.allocInit(ctx.arena);
    return _zx.ele(
        .html,
        .{
            .allocator = ctx.arena,
            .children = &.{
                _zx.ele(
                    .head,
                    .{
                        .children = &.{
                            _zx.ele(
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
                _zx.ele(
                    .body,
                    .{
                        .children = &.{
                            _zx.ele(
                                .nav,
                                .{
                                    .children = &.{
                                        _zx.ele(
                                            .a,
                                            .{
                                                .attributes = _zx.attrs(.{
                                                    _zx.attr("href", "/"),
                                                }),
                                                .children = &.{
                                                    _zx.txt("Home"),
                                                },
                                            },
                                        ),
                                        _zx.ele(
                                            .a,
                                            .{
                                                .attributes = _zx.attrs(.{
                                                    _zx.attr("href", "/about"),
                                                }),
                                                .children = &.{
                                                    _zx.txt("About"),
                                                },
                                            },
                                        ),
                                    },
                                },
                            ),
                            _zx.ele(
                                .main,
                                .{
                                    .children = &.{
                                        _zx.expr(children),
                                    },
                                },
                            ),
                            _zx.ele(
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
