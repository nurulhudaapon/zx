//! The FormData interface provides a way to construct a set of key/value pairs
//! representing form fields and their values, which can be sent using fetch()
//! or XMLHttpRequest.send().
//!
//! This implementation handles application/x-www-form-urlencoded data only.
//! For multipart/form-data with file uploads, use MultiFormData instead.
//!
//! https://developer.mozilla.org/en-US/docs/Web/API/FormData

const std = @import("std");

pub const FormData = @This();

// --- Types --- //

/// Entry type for iteration
pub const Entry = struct {
    key: []const u8,
    value: []const u8,
};

// --- Instance Fields --- //

/// Backend-specific context pointer
backend_ctx: ?*anyopaque = null,

/// VTable for backend-specific operations
vtable: ?*const VTable = null,

/// VTable interface for backend-specific FormData operations.
///
/// **Zig Note:** This is an internal type not present in the web standard.
pub const VTable = struct {
    /// Appends a new value onto an existing key, or adds the key if it doesn't exist
    append: *const fn (ctx: *anyopaque, name: []const u8, value: []const u8) void = &defaultAppend,
    /// Deletes a key/value pair
    delete: *const fn (ctx: *anyopaque, name: []const u8) void = &defaultDelete,
    /// Returns the first value associated with a given key
    get: *const fn (ctx: *anyopaque, name: []const u8) ?[]const u8 = &defaultGet,
    /// Returns all values associated with a given key
    getAll: *const fn (ctx: *anyopaque, name: []const u8, allocator: std.mem.Allocator) ?[]const []const u8 = &defaultGetAll,
    /// Returns whether the FormData contains a certain key
    has: *const fn (ctx: *anyopaque, name: []const u8) bool = &defaultHas,
    /// Sets a new value for an existing key, or adds the key/value if it doesn't exist
    set: *const fn (ctx: *anyopaque, name: []const u8, value: []const u8) void = &defaultSet,
    /// Returns an iterator over all entries
    entries: *const fn (ctx: *anyopaque) ?Iterator = &defaultEntries,

    fn defaultAppend(_: *anyopaque, _: []const u8, _: []const u8) void {}
    fn defaultDelete(_: *anyopaque, _: []const u8) void {}
    fn defaultGet(_: *anyopaque, _: []const u8) ?[]const u8 {
        return null;
    }
    fn defaultGetAll(_: *anyopaque, _: []const u8, _: std.mem.Allocator) ?[]const []const u8 {
        return null;
    }
    fn defaultHas(_: *anyopaque, _: []const u8) bool {
        return false;
    }
    fn defaultSet(_: *anyopaque, _: []const u8, _: []const u8) void {}
    fn defaultEntries(_: *anyopaque) ?Iterator {
        return null;
    }
};

// --- Instance Methods --- //
// https://developer.mozilla.org/en-US/docs/Web/API/FormData#instance_methods

/// Appends a new value onto an existing key inside a FormData object,
/// or adds the key if it does not already exist.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/append
pub fn append(self: *FormData, name: []const u8, value: []const u8) void {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            vt.append(ctx, name, value);
        }
    }
}

/// Deletes a key/value pair from a FormData object.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/delete
pub fn delete(self: *FormData, name: []const u8) void {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            vt.delete(ctx, name);
        }
    }
}

/// Returns the first value associated with a given key from within a FormData object.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/get
///
/// **Zig Note:** Returns `?[]const u8` instead of `FormDataEntryValue | null`.
pub fn get(self: *const FormData, name: []const u8) ?[]const u8 {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.get(ctx, name);
        }
    }
    return null;
}

/// Returns an array of all the values associated with a given key from within a FormData.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/getAll
///
/// **Zig Note:** Returns `?[]const []const u8` instead of `FormDataEntryValue[]`.
/// Requires an allocator for the returned slice.
pub fn getAll(self: *const FormData, name: []const u8, allocator: std.mem.Allocator) ?[]const []const u8 {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.getAll(ctx, name, allocator);
        }
    }
    return null;
}

/// Returns whether a FormData object contains a certain key.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/has
pub fn has(self: *const FormData, name: []const u8) bool {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.has(ctx, name);
        }
    }
    return false;
}

/// Sets a new value for an existing key inside a FormData object,
/// or adds the key/value if it does not already exist.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/set
///
/// **Zig Note:** Unlike `append()`, `set()` will overwrite all existing values
/// for the given key with the new value.
pub fn set(self: *FormData, name: []const u8, value: []const u8) void {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            vt.set(ctx, name, value);
        }
    }
}

// --- Iterator Methods --- //
// https://developer.mozilla.org/en-US/docs/Web/API/FormData#instance_methods

/// Returns an iterator that iterates through all key/value pairs contained in the FormData.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/entries
///
/// **Zig Note:** Returns a Zig iterator instead of a JavaScript iterator.
pub fn entries(self: *const FormData) ?Iterator {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.entries(ctx);
        }
    }
    return null;
}

/// Iterator for FormData entries
pub const Iterator = struct {
    pos: usize = 0,
    keys: []const []const u8,
    values: []const []const u8,

    /// Returns the next entry, or null if iteration is complete.
    pub fn next(self: *Iterator) ?Entry {
        if (self.pos >= self.keys.len) {
            return null;
        }
        const entry = Entry{
            .key = self.keys[self.pos],
            .value = self.values[self.pos],
        };
        self.pos += 1;
        return entry;
    }

    /// Resets the iterator to the beginning.
    pub fn reset(self: *Iterator) void {
        self.pos = 0;
    }
};

// --- Builder (for backend implementations) --- //

/// Builder for creating FormData objects.
///
/// **Zig Note:** This is an internal type not present in the web standard.
/// Used by backend adapters to construct FormData objects.
pub const Builder = struct {
    backend_ctx: ?*anyopaque = null,
    vtable: ?*const VTable = null,

    /// Builds the FormData object with all configured values.
    pub fn build(self: Builder) FormData {
        return .{
            .backend_ctx = self.backend_ctx,
            .vtable = self.vtable,
        };
    }
};

// --- Read-Only FormData (for parsed request bodies) --- //

/// A read-only FormData implementation backed by arrays of keys and values.
///
/// **Zig Note:** This is used for incoming request form data which is read-only.
/// It wraps the parsed form data from the backend without additional allocations.
pub const ReadOnly = struct {
    keys: []const []const u8,
    values: []const []const u8,
    len: usize,

    /// Creates a read-only FormData that delegates to this backing store.
    pub fn toFormData(self: *ReadOnly) FormData {
        return (Builder{
            .backend_ctx = @ptrCast(self),
            .vtable = &read_only_vtable,
        }).build();
    }

    /// Get the first value for a key.
    pub fn get(self: *const ReadOnly, name: []const u8) ?[]const u8 {
        for (self.keys[0..self.len], 0..) |key, i| {
            if (std.mem.eql(u8, key, name)) {
                return self.values[i];
            }
        }
        return null;
    }

    /// Check if a key exists.
    pub fn has(self: *const ReadOnly, name: []const u8) bool {
        return self.get(name) != null;
    }

    /// Get an iterator over all entries.
    pub fn iterator(self: *const ReadOnly) Iterator {
        return .{
            .keys = self.keys[0..self.len],
            .values = self.values[0..self.len],
        };
    }
};

const read_only_vtable = VTable{
    .get = &readOnlyGet,
    .has = &readOnlyHas,
    .entries = &readOnlyEntries,
    // Write operations are no-ops for read-only FormData
    .append = &VTable.defaultAppend,
    .delete = &VTable.defaultDelete,
    .set = &VTable.defaultSet,
    .getAll = &readOnlyGetAll,
};

fn readOnlyGet(ctx: *anyopaque, name: []const u8) ?[]const u8 {
    const self: *ReadOnly = @ptrCast(@alignCast(ctx));
    return self.get(name);
}

fn readOnlyHas(ctx: *anyopaque, name: []const u8) bool {
    const self: *ReadOnly = @ptrCast(@alignCast(ctx));
    return self.has(name);
}

fn readOnlyEntries(ctx: *anyopaque) ?Iterator {
    const self: *ReadOnly = @ptrCast(@alignCast(ctx));
    return self.iterator();
}

fn readOnlyGetAll(ctx: *anyopaque, name: []const u8, allocator: std.mem.Allocator) ?[]const []const u8 {
    const self: *ReadOnly = @ptrCast(@alignCast(ctx));
    var count: usize = 0;
    for (self.keys[0..self.len]) |key| {
        if (std.mem.eql(u8, key, name)) {
            count += 1;
        }
    }
    if (count == 0) return null;

    const result = allocator.alloc([]const u8, count) catch return null;
    var idx: usize = 0;
    for (self.keys[0..self.len], 0..) |key, i| {
        if (std.mem.eql(u8, key, name)) {
            result[idx] = self.values[i];
            idx += 1;
        }
    }
    return result;
}
