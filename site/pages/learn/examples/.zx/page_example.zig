pub fn Page(ctx: zx.PageContext) zx.Component {
    var _zx = zx.allocInit(ctx.arena);
    return _zx.ele(
        .main,
        .{
            .allocator = ctx.arena,
            .children = &.{
                _zx.ele(
                    .h1,
                    .{
                        .children = &.{
                            _zx.txt("About Us"),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Welcome to our website!"),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Path: "),
                            _zx.expr(ctx.request.url.path),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
