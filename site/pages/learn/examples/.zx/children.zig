pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.lazy(Card, .{ .title = "Welcome" }),
            },
        },
    );
}

const CardProps = struct { title: []const u8, children: zx.Component };
fn Card(allocator: zx.Allocator, props: CardProps) zx.Component {
    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .div,
        .{
            .allocator = allocator,
            .attributes = &.{
                .{ .name = "class", .value = "card" },
            },
            .children = &.{
                _zx.zx(
                    .h2,
                    .{
                        .children = &.{
                            _zx.txt(props.title),
                        },
                    },
                ),
                _zx.zx(
                    .div,
                    .{
                        .attributes = &.{
                            .{ .name = "class", .value = "card-body" },
                        },
                        .children = &.{
                            _zx.txt(props.children),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
