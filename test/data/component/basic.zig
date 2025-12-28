pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.cmp(Button, .{ .title = "Custom Button" }),
            },
        },
    );
}

const ButtonProps = struct { title: []const u8 };
pub fn Button(allocator: zx.Allocator, props: ButtonProps) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .button,
        .{
            .allocator = allocator,
            .attributes = _zx.attrs(.{
                _zx.attr("data-src", @src().file),
            }),
            .children = &.{
                _zx.expr(props.title),
            },
        },
    );
}

const zx = @import("zx");
