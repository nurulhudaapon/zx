const std = @import("std");

const Set = std.StaticStringMapWithEql(
    void,
    std.static_string_map.eqlAsciiIgnoreCase,
);

/// Known ZX builtin attribute names (including the `@` prefix).
pub const known = Set.initComptime(.{
    .{ "@allocator", {} },
    .{ "@client", {} },
    .{ "@escaping", {} },
    .{ "@async", {} },
    .{ "@caching", {} },
    .{ "@fallback", {} },
});

/// Builtins written without a value, e.g. `@client`.
const flags = Set.initComptime(.{
    .{ "@client", {} },
});

pub fn isKnown(name: []const u8) bool {
    return known.has(name);
}

pub fn isFlag(name: []const u8) bool {
    return flags.has(name);
}

/// True when `name` (without `@`) is a known builtin, e.g. `"allocator"` for `@{allocator}`.
pub fn isKnownShorthand(name: []const u8) bool {
    if (name.len == 0 or name.len + 1 > 64) return false;
    var buf: [64]u8 = undefined;
    buf[0] = '@';
    @memcpy(buf[1..][0..name.len], name);
    const full = buf[0 .. name.len + 1];
    return isKnown(full) and !isFlag(full);
}

/// All known builtin names including `@`, for completion / docs iteration.
pub fn names() []const []const u8 {
    return known.keys();
}
