pub fn Page(allocator: zx.Allocator) zx.Component {
    const user_name = "Alice";
    const greeting = "Welcome back";

    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.zx(
                    .h1,
                    .{
                        .children = &.{
                            _zx.txt(greeting),
                            _zx.txt(", "),
                            _zx.txt(user_name),
                            _zx.txt("!"),
                        },
                    },
                ),
                _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Your profile is ready."),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
