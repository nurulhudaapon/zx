pub fn Page(allocator: zx.Allocator) zx.Component {
    const products = [_][]const u8{ "Apple", "Banana", "Orange" };

    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.zx(
                    .h2,
                    .{
                        .children = &.{
                            _zx.txt("Products"),
                        },
                    },
                ),
                _zx.zx(
                    .ul,
                    .{
                        .children = blk: {
                            const __zx_children = _zx.getAllocator().alloc(zx.Component, products.len) catch unreachable;
                            for (products, 0..) |product, _zx_i| {
                                __zx_children[_zx_i] = _zx.zx(
                                    .li,
                                    .{
                                        .children = &.{
                                            _zx.txt(product),
                                        },
                                    },
                                );
                            }
                            break :blk __zx_children;
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
