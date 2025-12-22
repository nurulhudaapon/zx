pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .br,
                    .{},
                ),
                _zx.ele(
                    .hr,
                    .{},
                ),
                _zx.ele(
                    .input,
                    .{
                        .attributes = &.{
                            .{ .name = "type", .value = "text" },
                            .{ .name = "name", .value = "username" },
                        },
                    },
                ),
                _zx.ele(
                    .img,
                    .{
                        .attributes = &.{
                            .{ .name = "src", .value = "/logo.png" },
                            .{ .name = "alt", .value = "Logo" },
                        },
                    },
                ),
                _zx.ele(
                    .meta,
                    .{
                        .attributes = &.{
                            .{ .name = "charset", .value = "utf-8" },
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
