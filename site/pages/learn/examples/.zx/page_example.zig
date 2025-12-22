pub fn Page(ctx: zx.PageContext) zx.Component {
    var _zx = zx.initWithAllocator(ctx.arena);
    return _zx.zx(
        .main,
        .{
            .allocator = ctx.arena,
            .children = &.{
                _zx.zx(
                    .h1,
                    .{
                        .children = &.{
                            _zx.txt("About Us"),
                        },
                    },
                ),
                _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Welcome to our website!"),
                        },
                    },
                ),
                _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Path: "),
                            _zx.txt(ctx.request.url.path),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
