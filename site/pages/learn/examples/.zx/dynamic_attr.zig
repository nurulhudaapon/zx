pub fn Page(allocator: zx.Allocator) zx.Component {
    const class_name = "primary-btn";
    const user_id = "user-123";
    const is_active = true;

    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.zx(
                    .button,
                    .{
                        .attributes = &.{
                            .{ .name = "class", .value = class_name },
                            .{ .name = "id", .value = user_id },
                        },
                        .children = &.{
                            _zx.txt("\n                Submit\n            "),
                        },
                    },
                ),
                _zx.zx(
                    .div,
                    .{
                        .attributes = &.{
                            .{ .name = "class", .value = if (is_active) "active" else "inactive" },
                        },
                        .children = &.{
                            _zx.txt("\n                Dynamic class\n            "),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
