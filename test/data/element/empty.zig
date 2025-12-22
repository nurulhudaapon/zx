pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .div,
                    .{},
                ),
                _zx.ele(
                    .span,
                    .{
                        .attributes = &.{
                            .{ .name = "class", .value = "spacer" },
                        },
                    },
                ),
                _zx.ele(
                    .section,
                    .{
                        .attributes = &.{
                            .{ .name = "id", .value = "empty-section" },
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
