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
                            _zx.txt("Welcome to my app"),
                        },
                    },
                ),
                _zx.lazy(Greeting, .{}),
            },
        },
    );
}

fn Greeting(allocator: zx.Allocator) zx.Component {
    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .p,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.txt("Hello, World!"),
            },
        },
    );
}

const zx = @import("zx");
