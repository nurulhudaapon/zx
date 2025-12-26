pub fn Page(allocator: zx.Allocator) zx.Component {
    const count = 42;
    const name = "John";

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .section,
        .{
            .allocator = allocator,
            .attributes = _zx.attrs(.{
                _zx.attrf("class", "test-{s} {s}", .{
                    _zx.attrv(count),
                    _zx.attrv(getThemeClass(.dark)),
                }),
                _zx.attrf("data-name", "person-{s}", .{
                    _zx.attrv(name),
                }),
                _zx.attr("data-normal", name),
                _zx.attr("data-text", "{text}"),
                _zx.attr("data-t", "`{text}`"),
            }),
            .children = &.{
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("My name is "),
                            _zx.expr(name),
                        },
                    },
                ),
            },
        },
    );
}

const Theme = enum { light, dark };
fn getThemeClass(theme: Theme) []const u8 {
    return switch (theme) {
        .light => "theme-light",
        .dark => "theme-dark",
    };
}

const zx = @import("zx");
