pub fn DynamicAttrs(allocator: zx.Allocator) zx.Component {
    const class_name = "primary-btn";
    const user_id = "user-123";
    const is_active = true;

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .button,
                    .{
                        .attributes = _zx.attrs(.{
                            _zx.attr("class", class_name),
                            _zx.attr("id", user_id),
                        }),
                        .children = &.{
                            _zx.txt(" Submit"),
                        },
                    },
                ),
                _zx.ele(
                    .div,
                    .{
                        .attributes = _zx.attrs(.{
                            _zx.attr("class", if (is_active) "active" else "inactive"),
                        }),
                        .children = &.{
                            _zx.txt(" Dynamic class"),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
