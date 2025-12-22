pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.lazy(Button, .{ .title = "Submit", .class = "primary" }),
                _zx.lazy(Button, .{ .title = "Cancel" }),
                _zx.lazy(Button, .{}),
            },
        },
    );
}

const ButtonProps = struct {
    title: []const u8 = "Click Me",
    class: []const u8 = "btn",
};

fn Button(allocator: zx.Allocator, props: ButtonProps) zx.Component {
    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .button,
        .{
            .allocator = allocator,
            .attributes = &.{
                .{ .name = "class", .value = props.class },
            },
            .children = &.{
                _zx.txt(props.title),
            },
        },
    );
}

const zx = @import("zx");
