const std = @import("std");
const util = @import("util.zig");
const cli = @import("cli.zig");
const vorbis = @import("vorbis.zig");

/// Colors stores color codes for
/// output formatting
pub const Colors = struct {
    pub const green = "\x1b[92m";
    pub const red = "\x1b[91m";
    pub const yellow = "\x1b[93m";
    pub const reset = "\x1b[0m";
};

/// format calls the correct formatting function for a VorbisComment based on passed cli.OutMode.
/// Supports optional key filtering
pub fn format(alloc: std.mem.Allocator, vorbis_comment: *const vorbis.VorbisComment, mode: cli.OutMode, filter: ?util.StringArrayList) ![]u8 {
    return switch (mode) {
        .RawText => formatRaw(alloc, vorbis_comment, filter),
        .Pretty => formatPretty(alloc, vorbis_comment, filter),
        .Json => formatJSON(alloc, vorbis_comment, filter),
    };
}

/// formatRaw formats text similar to raw vorbis data: KEY=value.
/// Accepts a key filter list.
pub fn formatRaw(alloc: std.mem.Allocator, vorbis_comment: *const vorbis.VorbisComment, filter: ?util.StringArrayList) ![]u8 {
    var string = std.ArrayList(u8).init(alloc);

    var i: usize = 0;
    if (filter) |filtered_keys| {
        var iter = vorbis_comment.filterIter(filtered_keys);
        while (iter.next()) |tag| : (i += 1) {
            if (i > 0) _ = try string.writer().write("\n");

            _ = try string.writer().write(tag.key);
            _ = try string.writer().write("=");
            _ = try string.writer().write(tag.val);
        }
    } else {
        var iter = vorbis_comment.tags.iterator();
        while (iter.next()) |tag| : (i += 1) {
            if (i > 0) _ = try string.writer().write("\n");

            _ = try string.writer().write(tag.key_ptr.*);
            _ = try string.writer().write("=");
            _ = try string.writer().write(tag.value_ptr.*);
        }
    }

    return string.toOwnedSlice();
}

/// formatJSON encodes VorbisComment fields to json. Allows key filtering.
pub fn formatJSON(alloc: std.mem.Allocator, vorbis_comment: *const vorbis.VorbisComment, filter: ?util.StringArrayList) ![]u8 {
    var json_object = std.json.ObjectMap.init(alloc);
    defer json_object.deinit();

    if (filter) |filter_list| {
        var iter = vorbis_comment.filterIter(filter_list);
        while (iter.next()) |tag| {
            try json_object.put(tag.key, std.json.Value{ .string = tag.val });
        }
    } else {
        var iter = vorbis_comment.tags.iterator();
        while (iter.next()) |tag_entry| {
            try json_object.put(tag_entry.key_ptr.*, std.json.Value{ .string = tag_entry.value_ptr.* });
        }
    }

    const json_value = std.json.Value{ .object = json_object };
    var string = std.ArrayList(u8).init(alloc);
    defer string.deinit();
    try std.json.stringify(json_value, .{}, string.writer());

    return string.toOwnedSlice();
}

/// formatPretty formats a VorbisComment with color. Key: value
pub fn formatPretty(alloc: std.mem.Allocator, vorbis_comment: *const vorbis.VorbisComment, filter: ?util.StringArrayList) ![]u8 {
    var string = std.ArrayList(u8).init(alloc);
    defer string.deinit();

    var i: usize = 0;
    if (filter) |filter_list| {
        var iter = vorbis_comment.filterIter(filter_list);
        while (iter.next()) |tag| : (i += 1) {
            if (i > 0) _ = try string.writer().write("\n");

            const tag_fmt = try formatKV(alloc, tag.key, tag.val);
            defer alloc.free(tag_fmt);
            _ = try string.writer().write(tag_fmt);
        }
    } else {
        var tag_iter = vorbis_comment.tags.iterator();
        while (tag_iter.next()) |tag_entry| : (i += 1) {
            if (i > 0) _ = try string.writer().write("\n");

            const tag_fmt = try formatKV(alloc, tag_entry.key_ptr.*, tag_entry.value_ptr.*);
            defer alloc.free(tag_fmt);
            _ = try string.writer().write(tag_fmt);
        }
    }

    return string.toOwnedSlice();
}

/// formatKV formats a KV-pair with color
fn formatKV(alloc: std.mem.Allocator, key: []const u8, value: []const u8) ![]u8 {
    return try std.fmt.allocPrint(alloc, "\x1b[92m{s}\x1b[0m: {s}", .{ key, value });
}
