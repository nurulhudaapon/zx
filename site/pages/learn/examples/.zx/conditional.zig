pub fn UserStatus(allocator: zx.Allocator) zx.Component {
    const is_logged_in = true;
    const is_admin = false;

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                if (is_logged_in) _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Welcome back!"),
                        },
                    },
                ) else _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Please log in."),
                        },
                    },
                ),
                if (is_admin) _zx.ele(
                    .button,
                    .{
                        .children = &.{
                            _zx.txt("Admin Panel"),
                        },
                    },
                ) else _zx.ele(.fragment, .{}),
            },
        },
    );
}

const zx = @import("zx");
