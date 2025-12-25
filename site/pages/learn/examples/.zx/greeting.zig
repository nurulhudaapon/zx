pub fn HelloWorld(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .h1,
                    .{
                        .children = &.{
                            _zx.txt("Welcome to my app"),
                        },
                    },
                ),
                _zx.cmp(Greeting, .{}),
            },
        },
    );
}

fn Greeting(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
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
