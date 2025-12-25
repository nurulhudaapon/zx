pub fn RoleBadge(allocator: zx.Allocator) zx.Component {
    const role: Role = .admin;

    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.ele(
                    .span,
                    .{
                        .attributes = _zx.attrs(.{
                            _zx.attr("class", "badge"),
                        }),
                        .children = &.{
                            switch (role) {
                                .admin => _zx.ele(
                                    .strong,
                                    .{
                                        .children = &.{
                                            _zx.txt("Admin"),
                                        },
                                    },
                                ),
                                .member => _zx.txt("Member"),
                                .guest => _zx.txt("Guest"),
                            },
                        },
                    },
                ),
            },
        },
    );
}

const Role = enum { admin, member, guest };
const zx = @import("zx");
