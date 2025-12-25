pub fn ProductInfo(allocator: zx.Allocator) zx.Component {
    const price: f32 = 19.99;
    const quantity: u32 = 3;
    const is_available = true;

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Price: $"),
                            _zx.expr(price),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Quantity: "),
                            _zx.expr(quantity),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Available: "),
                            _zx.expr(is_available),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
