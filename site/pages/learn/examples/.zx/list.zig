pub fn ProductList(allocator: zx.Allocator) zx.Component {
    const products = [_][]const u8{ "Apple", "Banana", "Orange" };

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .h2,
                    .{
                        .children = &.{
                            _zx.txt("Products"),
                        },
                    },
                ),
                _zx.ele(
                    .ul,
                    .{
                        .children = &.{
                            _zx_for_blk_0: {
                                const __zx_children_0 = _zx.getAlloc().alloc(zx.Component, products.len) catch unreachable;
                                for (products, 0..) |product, _zx_i_0| {
                                    __zx_children_0[_zx_i_0] = _zx.ele(
                                        .li,
                                        .{
                                            .children = &.{
                                                _zx.expr(product),
                                            },
                                        },
                                    );
                                }
                                break :_zx_for_blk_0 _zx.ele(.fragment, .{ .children = __zx_children_0 });
                            },
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
