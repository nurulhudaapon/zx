pub fn Page(allocator: zx.Allocator) zx.Component {
    const role: Role = .admin;

    var _zx = zx.initWithAllocator(allocator);
    return _zx.zx(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                _zx.zx(
                    .span,
                    .{
                        .attributes = &.{
                            .{ .name = "class", .value = "badge" },
                        },
                        .children = &.{
                            switch (role) {
                                .admin => _zx.zx(
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
