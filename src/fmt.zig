const std = @import("std");

pub const Colors = struct {
    pub const green = "\x1b[92m";
    pub const red = "\x1b[91m";
    pub const yellow = "\x1b[93m";
    pub const reset = "\x1b[0m";
};

pub fn formatRaw(alloc: std.mem.Allocator, data: std.StringHashMap([]const u8), delim: []const u8) ![]u8 {
    var string = std.ArrayList(u8).init(alloc);

    var iter = data.iterator();
    while (iter.next()) |tag_entry| {
        _ = try string.writer().write(tag_entry.key_ptr.*);
        // _ = try string.writer().write(" ");
        _ = try string.writer().write(delim);
        // _ = try string.writer().write(" ");
        _ = try string.writer().write(tag_entry.value_ptr.*);
        _ = try string.writer().write("\n");
    }

    return string.toOwnedSlice();
}

pub fn formatJSON(alloc: std.mem.Allocator, data: std.StringHashMap([]const u8)) ![]u8 {
    var json_object = std.json.ObjectMap.init(alloc);
    defer json_object.deinit();

    var iter = data.iterator();
    while (iter.next()) |tag_entry| {
        try json_object.put(tag_entry.key_ptr.*, std.json.Value{ .string = tag_entry.value_ptr.* });
    }
    const json_value = std.json.Value{ .object = json_object };
    var string = std.ArrayList(u8).init(alloc);
    defer string.deinit();

    try std.json.stringify(json_value, .{}, string.writer());

    return string.toOwnedSlice();
}

pub fn formatPretty(alloc: std.mem.Allocator, data: std.StringHashMap([]const u8)) ![]u8 {
    var string = std.ArrayList(u8).init(alloc);

    var tag_iter = data.iterator();
    while (tag_iter.next()) |tag_entry| {
        const tag_fmt = try formatKV(alloc, tag_entry.key_ptr.*, tag_entry.value_ptr.*);
        defer alloc.free(tag_fmt);
        _ = try string.writer().write(tag_fmt);
        _ = try string.writer().write("\n");
    }

    return string.toOwnedSlice();
}

fn formatKV(alloc: std.mem.Allocator, key: []const u8, value: []const u8) ![]u8 {
    return try std.fmt.allocPrint(alloc, "\x1b[92m{s}\x1b[0m: {s}", .{ key, value });
}
