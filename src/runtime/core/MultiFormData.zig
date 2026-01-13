//! The MultiFormData interface provides a way to construct a set of key/value pairs
//! representing multipart form fields and their values, including file uploads.
//!
//! This implementation handles multipart/form-data with file upload support.
//! For simple key-value form data (application/x-www-form-urlencoded), use FormData instead.
//!
//! https://developer.mozilla.org/en-US/docs/Web/API/FormData

const std = @import("std");

pub const MultiFormData = @This();

// --- Types --- //

/// A single form data entry value, which can be a string or a file.
///
/// **Zig Note:** In the web standard, values can be `string | Blob`.
/// This implementation uses a struct that can represent both.
pub const Value = struct {
    /// The value content as bytes
    data: []const u8,
    /// Optional filename for file uploads (null for regular fields)
    filename: ?[]const u8 = null,

    /// Returns true if this entry represents a file upload
    pub fn isFile(self: Value) bool {
        return self.filename != null;
    }
};

/// Entry type for iteration
pub const Entry = struct {
    key: []const u8,
    value: Value,
};

// --- Instance Fields --- //

/// Backend-specific context pointer
backend_ctx: ?*anyopaque = null,

/// VTable for backend-specific operations
vtable: ?*const VTable = null,

/// VTable interface for backend-specific MultiFormData operations.
///
/// **Zig Note:** This is an internal type not present in the web standard.
pub const VTable = struct {
    /// Appends a new value onto an existing key, or adds the key if it doesn't exist
    append: *const fn (ctx: *anyopaque, name: []const u8, value: Value) void = &defaultAppend,
    /// Deletes a key/value pair
    delete: *const fn (ctx: *anyopaque, name: []const u8) void = &defaultDelete,
    /// Returns the first value associated with a given key
    get: *const fn (ctx: *anyopaque, name: []const u8) ?Value = &defaultGet,
    /// Returns all values associated with a given key
    getAll: *const fn (ctx: *anyopaque, name: []const u8, allocator: std.mem.Allocator) ?[]const Value = &defaultGetAll,
    /// Returns whether the MultiFormData contains a certain key
    has: *const fn (ctx: *anyopaque, name: []const u8) bool = &defaultHas,
    /// Sets a new value for an existing key, or adds the key/value if it doesn't exist
    set: *const fn (ctx: *anyopaque, name: []const u8, value: Value) void = &defaultSet,
    /// Returns an iterator over all entries
    entries: *const fn (ctx: *anyopaque) ?Iterator = &defaultEntries,

    fn defaultAppend(_: *anyopaque, _: []const u8, _: Value) void {}
    fn defaultDelete(_: *anyopaque, _: []const u8) void {}
    fn defaultGet(_: *anyopaque, _: []const u8) ?Value {
        return null;
    }
    fn defaultGetAll(_: *anyopaque, _: []const u8, _: std.mem.Allocator) ?[]const Value {
        return null;
    }
    fn defaultHas(_: *anyopaque, _: []const u8) bool {
        return false;
    }
    fn defaultSet(_: *anyopaque, _: []const u8, _: Value) void {}
    fn defaultEntries(_: *anyopaque) ?Iterator {
        return null;
    }
};

// --- Instance Methods --- //
// https://developer.mozilla.org/en-US/docs/Web/API/FormData#instance_methods

/// Appends a new value onto an existing key inside a MultiFormData object,
/// or adds the key if it does not already exist.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/append
///
/// **Zig Note:** In the web standard, this accepts (name, value) or (name, blob, filename).
/// This implementation uses a Value struct that can represent both cases.
pub fn append(self: *MultiFormData, name: []const u8, value: Value) void {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            vt.append(ctx, name, value);
        }
    }
}

/// Appends a string value.
///
/// **Zig Note:** Convenience method for appending simple string values.
pub fn appendValue(self: *MultiFormData, name: []const u8, value: []const u8) void {
    self.append(name, .{ .data = value });
}

/// Appends a file value with filename.
///
/// **Zig Note:** Convenience method for appending file uploads.
pub fn appendFile(self: *MultiFormData, name: []const u8, data: []const u8, filename: []const u8) void {
    self.append(name, .{ .data = data, .filename = filename });
}

/// Deletes a key/value pair from a MultiFormData object.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/delete
pub fn delete(self: *MultiFormData, name: []const u8) void {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            vt.delete(ctx, name);
        }
    }
}

/// Returns the first value associated with a given key from within a MultiFormData object.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/get
///
/// **Zig Note:** Returns `?Value` instead of `FormDataEntryValue | null`.
pub fn get(self: *const MultiFormData, name: []const u8) ?Value {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.get(ctx, name);
        }
    }
    return null;
}

/// Returns the first string value associated with a given key.
///
/// **Zig Note:** Convenience method that returns just the data portion.
pub fn getValue(self: *const MultiFormData, name: []const u8) ?[]const u8 {
    if (self.get(name)) |v| {
        return v.data;
    }
    return null;
}

/// Returns an array of all the values associated with a given key from within a MultiFormData.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/getAll
///
/// **Zig Note:** Returns `?[]const Value` instead of `FormDataEntryValue[]`.
/// Requires an allocator for the returned slice.
pub fn getAll(self: *const MultiFormData, name: []const u8, allocator: std.mem.Allocator) ?[]const Value {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.getAll(ctx, name, allocator);
        }
    }
    return null;
}

/// Returns whether a MultiFormData object contains a certain key.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/has
pub fn has(self: *const MultiFormData, name: []const u8) bool {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.has(ctx, name);
        }
    }
    return false;
}

/// Sets a new value for an existing key inside a MultiFormData object,
/// or adds the key/value if it does not already exist.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/set
///
/// **Zig Note:** Unlike `append()`, `set()` will overwrite all existing values
/// for the given key with the new value.
pub fn set(self: *MultiFormData, name: []const u8, value: Value) void {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            vt.set(ctx, name, value);
        }
    }
}

/// Sets a string value.
///
/// **Zig Note:** Convenience method for setting simple string values.
pub fn setValue(self: *MultiFormData, name: []const u8, value: []const u8) void {
    self.set(name, .{ .data = value });
}

/// Sets a file value with filename.
///
/// **Zig Note:** Convenience method for setting file uploads.
pub fn setFile(self: *MultiFormData, name: []const u8, data: []const u8, filename: []const u8) void {
    self.set(name, .{ .data = data, .filename = filename });
}

// --- Iterator Methods --- //
// https://developer.mozilla.org/en-US/docs/Web/API/FormData#instance_methods

/// Returns an iterator that iterates through all key/value pairs contained in the MultiFormData.
///
/// https://developer.mozilla.org/en-US/docs/Web/API/FormData/entries
///
/// **Zig Note:** Returns a Zig iterator instead of a JavaScript iterator.
pub fn entries(self: *const MultiFormData) ?Iterator {
    if (self.vtable) |vt| {
        if (self.backend_ctx) |ctx| {
            return vt.entries(ctx);
        }
    }
    return null;
}

/// Iterator for MultiFormData entries
pub const Iterator = struct {
    pos: usize = 0,
    keys: []const []const u8,
    values: []const Value,

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

/// Builder for creating MultiFormData objects.
///
/// **Zig Note:** This is an internal type not present in the web standard.
/// Used by backend adapters to construct MultiFormData objects.
pub const Builder = struct {
    backend_ctx: ?*anyopaque = null,
    vtable: ?*const VTable = null,

    /// Builds the MultiFormData object with all configured values.
    pub fn build(self: Builder) MultiFormData {
        return .{
            .backend_ctx = self.backend_ctx,
            .vtable = self.vtable,
        };
    }
};

// --- Read-Only MultiFormData (for parsed request bodies) --- //

/// A read-only MultiFormData implementation backed by arrays of keys and values.
///
/// **Zig Note:** This is used for incoming request form data which is read-only.
/// It wraps the parsed form data from the backend without additional allocations.
pub const ReadOnly = struct {
    keys: []const []const u8,
    values: []const Value,
    len: usize,

    /// Creates a read-only MultiFormData that delegates to this backing store.
    pub fn toMultiFormData(self: *ReadOnly) MultiFormData {
        return (Builder{
            .backend_ctx = @ptrCast(self),
            .vtable = &read_only_vtable,
        }).build();
    }

    /// Get the first value for a key.
    pub fn get(self: *const ReadOnly, name: []const u8) ?Value {
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
    // Write operations are no-ops for read-only MultiFormData
    .append = &VTable.defaultAppend,
    .delete = &VTable.defaultDelete,
    .set = &VTable.defaultSet,
    .getAll = &readOnlyGetAll,
};

fn readOnlyGet(ctx: *anyopaque, name: []const u8) ?Value {
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

fn readOnlyGetAll(ctx: *anyopaque, name: []const u8, allocator: std.mem.Allocator) ?[]const Value {
    const self: *ReadOnly = @ptrCast(@alignCast(ctx));
    var count: usize = 0;
    for (self.keys[0..self.len]) |key| {
        if (std.mem.eql(u8, key, name)) {
            count += 1;
        }
    }
    if (count == 0) return null;

    const result = allocator.alloc(Value, count) catch return null;
    var idx: usize = 0;
    for (self.keys[0..self.len], 0..) |key, i| {
        if (std.mem.eql(u8, key, name)) {
            result[idx] = self.values[i];
            idx += 1;
        }
    }
    return result;
}
