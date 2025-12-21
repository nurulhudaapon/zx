pub fn Page(allocator: zx.Allocator) zx.Component {
    const users = [_]struct { name: []const u8, role: UserRole }{
        .{ .name = "John", .role = .admin },
        .{ .name = "Jane", .role = .member },
        .{ .name = "Jim", .role = .guest },
    };
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                blk_0: {
                    const __zx_children_0 = _zx.getAlloc().alloc(zx.Component, users.len) catch unreachable;
                    for (users, 0..) |user, _zx_i_0| {
                        __zx_children_0[_zx_i_0] = _zx.ele(
                            .div,
                            .{
                                .children = &.{
                                    _zx.ele(
                                        .p,
                                        .{
                                            .children = &.{
                                                _zx.expr(user.name),
                                            },
                                        },
                                    ),
                                    switch (user.role) {
                                        .admin => _zx.ele(
                                            .span,
                                            .{
                                                .children = &.{
                                                    _zx.txt("Admin"),
                                                },
                                            },
                                        ),
                                        .member => _zx.ele(
                                            .span,
                                            .{
                                                .children = &.{
                                                    _zx.txt("Member"),
                                                },
                                            },
                                        ),
                                        .guest => _zx.ele(
                                            .span,
                                            .{
                                                .children = &.{
                                                    _zx.txt("Guest"),
                                                },
                                            },
                                        ),
                                    },
                                },
                            },
                        );
                    }
                    break :blk_0 _zx.ele(.fragment, .{ .children = __zx_children_0 });
                },
            },
        },
    );
}

const zx = @import("zx");

const UserRole = enum { admin, member, guest };
