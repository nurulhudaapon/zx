pub fn ButtonDemo(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.cmp(Button, .{ .title = "Submit", .class = "primary" }),
                _zx.cmp(Button, .{ .title = "Cancel" }),
                _zx.cmp(Button, .{}),
            },
        },
    );
}

const ButtonProps = struct {
    title: []const u8 = "Click Me",
    class: []const u8 = "btn",
};

fn Button(allocator: zx.Allocator, props: ButtonProps) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .button,
        .{
            .allocator = allocator,
            .attributes = _zx.attrs(.{
                _zx.attr("class", props.class),
            }),
            .children = &.{
                _zx.expr(props.title),
            },
        },
    );
}

const zx = @import("zx");
