pub extern "zig-js" fn valueGet(out: *u64, id: u32, addr: [*]const u8, len: usize) void;
pub extern "zig-js" fn valueSet(id: u32, addr: [*]const u8, len: usize, refPtr: *const u64) void;
pub extern "zig-js" fn valueObjectCreate(out: *u64) void;
pub extern "zig-js" fn valueStringCreate(out: *u64, addr: [*]const u8, len: usize) void;
pub extern "zig-js" fn valueStringLen(id: u32) u32;
pub extern "zig-js" fn valueStringCopy(id: u32, addr: [*]u8, max: usize) void;
pub extern "zig-js" fn valueDeinit(id: u32) void;
pub extern "zig-js" fn valueNew(out: *u64, id: u32, argsPtr: [*]const u64, argsLen: usize) void;
pub extern "zig-js" fn funcApply(
    out: *u64,
    func: u32,
    thisPtr: *const u64,
    argsPtr: [*]const u64,
    argsLen: usize,
) void;
