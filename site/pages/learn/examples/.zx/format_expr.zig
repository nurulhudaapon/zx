pub fn Page(allocator: zx.Allocator) zx.Component {
    const price: f32 = 19.99;
    const quantity: u32 = 3;
    const is_available = true;

    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Price: $"),
                            _zx.txt(price),
                        },
                    },
                ),
                _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Quantity: "),
                            _zx.txt(quantity),
                        },
                    },
                ),
                _zx.zx(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("Available: "),
                            _zx.txt(is_available),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
