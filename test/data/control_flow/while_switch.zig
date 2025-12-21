pub fn Page(allocator: zx.Allocator) zx.Component {
    var i: usize = 0;

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                blk_0: {
                    var __zx_list_0 = @import("std").ArrayList(zx.Component).empty;
                    while (i < 3) : (i += 1) {
                        __zx_list_0.append(_zx.getAlloc(), _zx.ele(
                            .div,
                            .{
                                .children = &.{
                                    switch (i) {
                                        0 => _zx.ele(
                                            .span,
                                            .{
                                                .children = &.{
                                                    _zx.txt("Zero"),
                                                },
                                            },
                                        ),
                                        1 => _zx.ele(
                                            .span,
                                            .{
                                                .children = &.{
                                                    _zx.txt("One"),
                                                },
                                            },
                                        ),
                                        else => _zx.ele(
                                            .span,
                                            .{
                                                .children = &.{
                                                    _zx.txt("Other"),
                                                },
                                            },
                                        ),
                                    },
                                },
                            },
                        )) catch unreachable;
                    }
                    break :blk_0 _zx.ele(.fragment, .{ .children = __zx_list_0.items });
                },
            },
        },
    );
}

const zx = @import("zx");
