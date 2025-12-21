pub fn Page(allocator: zx.Allocator) zx.Component {
    const hello_child = _zx_ele_blk_0: {
        var _zx = zx.allocInit(allocator);
        break :_zx_ele_blk_0 _zx.ele(
            .div,
            .{
                .allocator = allocator,
                .children = &.{
                    _zx.txt("Hello!"),
                },
            },
        );
    };
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .section,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.cmp(ChildComponent, .{ .children = hello_child }),
                _zx.cmp(ChildComponent, .{ .children = _zx.ele(
                    .div,
                    .{
                        .children = &.{
                            _zx.txt("Hello!"),
                        },
                    },
                ) }),
            },
        },
    );
}

const hello_child_outside = _zx_ele_blk_1: {
    var _zx = zx.allocInit(std.heap.page_allocator);
    break :_zx_ele_blk_1 _zx.ele(
        .div,
        .{
            .allocator = std.heap.page_allocator,
            .children = &.{
                _zx.txt("Hello!"),
            },
        },
    );
};

const Props = struct { children: zx.Component };
pub fn ChildComponent(allocator: zx.Allocator, props: Props) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .div,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.expr(props.children),
            },
        },
    );
}

const zx = @import("zx");
const std = @import("std");
