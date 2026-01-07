pub const components = [_]zx.Client.ComponentMeta{
 .{
    .type = .client,
    .id = "c8fee6a",
    .name = "CounterComponent",
    .path = "component/csr_zig.zig",
    .import = zx.Client.ComponentMeta.init(@import("component/csr_zig.zig").CounterComponent),
    .route = "",
}, .{
    .type = .client,
    .id = "cd02624",
    .name = "Button",
    .path = "component/csr_zig.zig",
    .import = zx.Client.ComponentMeta.init(@import("component/csr_zig.zig").Button),
    .route = "",
} };

const zx = @import("zx");
