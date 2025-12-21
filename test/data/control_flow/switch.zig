pub fn Page(allocator: zx.Allocator) zx.Component {
    const user_type: UserType = .admin;
    var _zx = zx.allocInit(allocator);
    return _zx.ele(
        .main,
        .{
            .allocator = allocator,
            .children = &.{
                switch (user_type) {
                    .admin => _zx.txt("Admin"),
                    .member => _zx.txt("Member"),
                },
            },
        },
    );
}

const zx = @import("zx");

const UserType = enum { admin, member };
