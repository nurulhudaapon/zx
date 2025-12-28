pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .section,
        .{
            .allocator = allocator,
            .attributes = _zx.attrs(.{
                _zx.attr("data-src", @src().file),
            }),
            .children = &.{
                _zx.ele(
                    .pre,
                    .{
                        .children = &.{
                            _zx.txt("                \n"),
                            _zx.expr(
                                \\const data = 
                                \\
                                \\ Test 
                                \\ Test 2
                                \\
                                \\ name: "test" ;
                                \\
                                \\
                            ),
                            _zx.txt("            "),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
