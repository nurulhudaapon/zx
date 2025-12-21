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

const zx = @import("zx");
const Button = @import("basic.zig").Button;

// const ClientComponent = @jsImport("basic.tsx");
