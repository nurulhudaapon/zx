pub fn Page(allocator: zx.Allocator) zx.Component {
    var i: usize = 0;

    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                blk: {
                    var __zx_list = @import("std").ArrayList(zx.Component).empty;
                    while (i < 3) : (i += 1) {
                        __zx_list.append(_zx.getAllocator(), _zx.zx(
                            .div,
                            .{
                                .children = &.{
                                    _zx.zx(
                                        .p,
                                        .{
                                            .children = &.{
                                                _zx.fmt("{d}", .{i}),
                                            },
                                        },
                                    ),
                                },
                            },
                        )) catch unreachable;
                    }
                    break :blk _zx.zx(.fragment, .{ .children = __zx_list.items });
                },
            },
        },
    );
}

const zx = @import("zx");
