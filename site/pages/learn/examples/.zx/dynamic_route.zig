// site/pages/user/[id]/page.zx
pub fn UserProfile(ctx: zx.PageContext) zx.Component {
    const user_id = ctx.request.param("id") orelse "unknown";

    var _zx = zx.allocInit(ctx.arena);
    return _zx.ele(
        .main,
        .{
            .allocator = ctx.arena,
            .children = &.{
                _zx.ele(
                    .h1,
                    .{
                        .children = &.{
                            _zx.txt("User Profile"),
                        },
                    },
                ),
                _zx.ele(
                    .p,
                    .{
                        .children = &.{
                            _zx.txt("User ID: "),
                            _zx.expr(user_id),
                        },
                    },
                ),
            },
        },
    );
}

const zx = @import("zx");
