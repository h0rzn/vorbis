const std = @import("std");
const util = @import("util.zig");
const cli = @import("cli.zig");

pub const Colors = struct {
    pub const green = "\x1b[92m";
    pub const red = "\x1b[91m";
    pub const yellow = "\x1b[93m";
    pub const reset = "\x1b[0m";
};

pub fn format(alloc: std.mem.Allocator, data: std.StringHashMap([]const u8), mode: cli.OutMode, filter: ?util.StringArrayList) ![]u8 {
    return switch (mode) {
        .RawText => formatRaw(alloc, data, filter),
        .Pretty => formatPretty(alloc, data, filter),
        .Json => formatJSON(alloc, data, filter),
    };
}

pub fn formatRaw(alloc: std.mem.Allocator, data: std.StringHashMap([]const u8), filter: ?util.StringArrayList) ![]u8 {
    var string = std.ArrayList(u8).init(alloc);

    if (filter) |*filter_list| {
        var filter_iter = filter_list.iter();
        const filter_count = filter_list.count() - 1;
        var i: usize = 0;
        while (filter_iter.next()) |key| {
            var upper_key_buf: [100]u8 = undefined;
            const upper_key = std.ascii.upperString(&upper_key_buf, key);
            const value = data.get(upper_key);
            _ = try string.writer().write(upper_key);
            _ = try string.writer().write("=");
            if (value) |v| {
                _ = try string.writer().write(v);
            } else {
                _ = try string.writer().write("<unkown>");
            }

            if (i < filter_count) {
                _ = try string.writer().write("\n");
                i += 1;
            }
        }
    } else {
        var iter = data.iterator();
        const len = data.count() - 1;
        var i: usize = 0;
        while (iter.next()) |tag_entry| {
            _ = try string.writer().write(tag_entry.key_ptr.*);
            _ = try string.writer().write("=");
            _ = try string.writer().write(tag_entry.value_ptr.*);

            if (i < len) {
                _ = try string.writer().write("\n");
                i += 1;
            }
        }
    }

    return string.toOwnedSlice();
}

pub fn formatJSON(alloc: std.mem.Allocator, data: std.StringHashMap([]const u8), filter: ?util.StringArrayList) ![]u8 {
    var json_object = std.json.ObjectMap.init(alloc);
    defer json_object.deinit();

    if (filter) |*filter_list| {
        var filter_iter = filter_list.iter();
        while (filter_iter.next()) |key| {
            var upper_key_buf: [100]u8 = undefined;
            const upper_key = std.ascii.upperString(&upper_key_buf, key);
            const value = data.get(upper_key);
            if (value) |v| {
                try json_object.put(key, std.json.Value{ .string = v });
            } else {
                try json_object.put(key, std.json.Value{ .string = "<unkown>" });
            }
        }
    } else {
        var iter = data.iterator();
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

pub fn formatPretty(alloc: std.mem.Allocator, data: std.StringHashMap([]const u8), filter: ?util.StringArrayList) ![]u8 {
    var string = std.ArrayList(u8).init(alloc);
    defer string.deinit();

    if (filter) |*filter_list| {
        var filter_iter = filter_list.iter();
        const filter_count = filter_list.count() - 1;
        var i: usize = 0;
        while (filter_iter.next()) |key| {
            var upper_key_buf: [100]u8 = undefined;
            const upper_key = std.ascii.upperString(&upper_key_buf, key);
            const value = data.get(upper_key);
            if (value) |v| {
                const tag_fmt = try formatKV(alloc, upper_key, v);
                defer alloc.free(tag_fmt);
                _ = try string.writer().write(tag_fmt);
            } else {
                const tag_fmt = try formatKV(alloc, upper_key, "<unkown>");
                defer alloc.free(tag_fmt);
                _ = try string.writer().write(tag_fmt);
            }

            if (i < filter_count) {
                _ = try string.writer().write("\n");
                i += 1;
            }
        }
    } else {
        var tag_iter = data.iterator();
        while (tag_iter.next()) |tag_entry| {
            const tag_fmt = try formatKV(alloc, tag_entry.key_ptr.*, tag_entry.value_ptr.*);
            defer alloc.free(tag_fmt);
            _ = try string.writer().write(tag_fmt);
            _ = try string.writer().write("\n");
        }
    }

    return try string.toOwnedSlice();
}

pub fn formatKV(alloc: std.mem.Allocator, key: []const u8, value: []const u8) ![]u8 {
    return try std.fmt.allocPrint(alloc, "\x1b[92m{s}\x1b[0m: {s}", .{ key, value });
}
