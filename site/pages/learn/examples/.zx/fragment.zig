pub fn Page(allocator: zx.Allocator) zx.Component {
    var _zx= zx.initWithAllocator (allocator);
return _zx.zx (
        .main,
        .{
            .allocator= allocator,
            .children=&.{
                _zx.lazy (Header, .{}),
            },
        },
    );
}

fn Header(allocator: zx.Allocator) zx.Component {
    return (
        <>
            <h1 @allocator={allocator}>Welcome</h1>
            <p>Multiple elements without a wrapper</p>
        </>
    );
}

const zx = @import("zx");

