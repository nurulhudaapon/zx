pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.client(.{ .name = "CounterComponent", .path = "test/data/component/csr_zig.zig", .id = "zx-2676a2f99c98f8f91dd890d002af04ba-0" }, .{}),
            },
        },
    );
}

pub fn CounterComponent(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .button,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.txt("Counter"),
            },
        },
    );
}

const zx = @import("zx");
