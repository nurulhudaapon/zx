pub fn Page(allocator: zx.Allocator) zx.Component {
    const class_name = "container";
    const is_active = true;
    const id = "main-content";

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .div,
                    .{
                        .attributes = &.{
                            .{ .name = "class", .value = class_name },
                            .{ .name = "id", .value = id },
                        },
                        .children = &.{
                            _zx.ele(
                                .button,
                                .{
                                    .attributes = &.{
                                        .{ .name = "class", .value = if (is_active) "active" else "inactive" },
                                    },
                                    .children = &.{
                                        _zx.txt(" Click me"),
                                    },
                                },
                            ),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
