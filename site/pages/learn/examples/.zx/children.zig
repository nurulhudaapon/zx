pub fn CardDemo(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.cmp(Card, .{ .title = "Welcome", .children = _zx.ele(.fragment, .{ .children = &.{
                    _zx.ele(
                        .p,
                        .{
                            .children = &.{
                                _zx.txt("This content is passed as children."),
                            },
                        },
                    ),
                    _zx.ele(
                        .button,
                        .{
                            .children = &.{
                                _zx.txt("Click me"),
                            },
                        },
                    ),
                } }) }),
            },
        },
    );
}

const CardProps = struct { title: []const u8, children: zx.Component };
fn Card(allocator: zx.Allocator, props: CardProps) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .div,
        .{
            .allocator = allocator,
            .attributes = _zx.attrs(.{
                _zx.attr("class", "card"),
            }),
            .children = &.{
                _zx.ele(
                    .h2,
                    .{
                        .children = &.{
                            _zx.expr(props.title),
                        },
                    },
                ),
                _zx.ele(
                    .div,
                    .{
                        .attributes = _zx.attrs(.{
                            _zx.attr("class", "card-body"),
                        }),
                        .children = &.{
                            _zx.expr(props.children),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
