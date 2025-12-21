pub fn Page(allocator: zx.Allocator) zx.Component {
    const count = 42;
    const hex_value = 255;
    const percentage = 75;
    const float_value = 3.14;
    const bool_value = true;

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .section,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Count: "),
                            _zx.fmt("{d}", .{count}),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Hex: 0x"),
                            _zx.fmt("{x}", .{hex_value}),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Percentage: "),
                            _zx.fmt("{d}", .{percentage}),
                            _zx.txt("%"),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Count: "),
                            _zx.expr(count),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Hex: 0x"),
                            _zx.expr(hex_value),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Percentage: "),
                            _zx.expr(percentage),
                            _zx.txt("%"),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Float: "),
                            _zx.expr(float_value),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Bool: "),
                            _zx.expr(bool_value),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
