pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .section,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .div,
                    .{
                        .children = &.{
                            _zx.txt("\n                const data = name:\n                Test   \n                        Test 2\n                \n                 test ;\n            "),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
