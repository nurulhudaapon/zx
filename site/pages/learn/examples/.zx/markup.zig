pub fn Page(allocator: zx.Allocator) zx.Component {
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
                            _zx.txt("About"),
                        },
                    },
                ),
                _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Hello there."),
                            _zx.zx(
                                .br,
                                .{},
                            ),
                            _zx.txt("How are you?"),
                        },
                    },
                ),
                _zx.lazy(Card, .{}),
            },
        },
    );
}

fn Card(allocator: zx.Allocator) zx.Component {
    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .div,
        .{
            .allocator = allocator,
            .attributes = &.{
                .{ .name = "class", .value = "card" },
            },
            .children = &.{
                _zx.zx(
                    .h2,
                    .{
                        .children = &.{
                            _zx.txt("User Profile"),
                        },
                    },
                ),
                _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Welcome to the card component!"),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
