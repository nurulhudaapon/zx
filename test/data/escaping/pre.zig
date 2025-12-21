pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .section,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .pre,
                    .{
                        .children = &.{
                            _zx.txt("                const data = \n"),
                            _zx.txt("                \n"),
                            _zx.txt("                Test   \n"),
                            _zx.txt("                        Test 2\n"),
                            _zx.txt("                \n"),
                            _zx.txt("                 name: \"test\" ;\n"),
                            _zx.txt("            "),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
