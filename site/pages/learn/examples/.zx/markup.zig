pub fn AboutSection(allocator: zx.Allocator) zx.Component {
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
                            _zx.txt("About"),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Hello there."),
                            _zx.ele(
                                .br,
                                .{},
                            ),
                            _zx.txt("How are you?"),
                        },
                    },
                ),
                _zx.cmp(Card, .{}),
            },
        },
    );
}

fn Card(allocator: zx.Allocator) zx.Component {
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
                            _zx.txt("User Profile"),
                        },
                    },
                ),
                _zx.ele(
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
