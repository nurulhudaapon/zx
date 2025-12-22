pub fn Page(allocator: zx.Allocator) zx.Component {
    const is_logged_in = true;
    const is_admin = false;

    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                if ((is_logged_in)) _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Welcome back!"),
                        },
                    },
                ) else _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Please log in."),
                        },
                    },
                ),
                if ((is_admin)) _zx.zx(
                    .button,
                    .{
                        .children = &.{
                            _zx.txt("Admin Panel"),
                        },
                    },
                ) else _zx.zx(
                    .fragment,
                    .{},
                ),
            },
        },
    );
}

const zx = @import("zx");
