pub fn FragmentDemo(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.cmp(Header, .{}),
            },
        },
    );
}

fn Header(allocator: zx.Allocator) zx.Component {
    var _zx = zx.init();
    return _zx.ele(
        .fragment,
        .{
            .children = &.{
                _zx.ele(
                    .h1,
                    .{
                        .allocator = allocator,
                        .children = &.{
                            _zx.txt("Welcome"),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Multiple elements without a wrapper"),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
