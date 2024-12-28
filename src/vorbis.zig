const std = @import("std");
const fs = std.fs;
const fmt = @import("fmt.zig");
const Reader = @import("reader.zig").Reader;
const StringArrayList = @import("util.zig").StringArrayList;

pub const SIGNATURE = [6]u8{ 0x76, 0x6f, 0x72, 0x62, 0x69, 0x73 }; // ASCII: vorbis

pub const VorbisError = error{
    PacketBadLength,
};

pub fn parseVorbisComment(allocator: std.mem.Allocator, block: []u8) !VorbisComment {
    if (block.len <= 4) return VorbisError.PacketBadLength;

    var stream = std.io.fixedBufferStream(block);
    var stream_reader = stream.reader();

    const vendor_length = try stream_reader.readInt(u32, std.builtin.Endian.little);
    const vendor_string = try allocator.alloc(u8, vendor_length);
    errdefer allocator.free(vendor_string);
    try stream_reader.readNoEof(vendor_string);

    const user_comment_list_length = try stream_reader.readInt(u32, std.builtin.Endian.little);
    var tags = std.StringHashMap([]const u8).init(allocator);
    var comment_index: i32 = 0;
    while (comment_index < user_comment_list_length) : (comment_index = comment_index + 1) {
        const comment_length = try stream_reader.readInt(u32, std.builtin.Endian.little);

        const comment = try allocator.alloc(u8, comment_length);
        errdefer allocator.free(comment);
        try stream_reader.readNoEof(comment);
        const vorbis_tag = try split(allocator, comment);

        try tags.put(vorbis_tag.key, vorbis_tag.val);

        allocator.free(comment);
    }

    return .{
        .vendor_string = vendor_string,
        .tags = tags,
    };
}

pub const VorbisTag = struct {
    key: []const u8,
    val: []const u8,
};

fn split(alloc: std.mem.Allocator, comment: []const u8) !VorbisTag {
    var splits = std.mem.split(u8, comment, "=");
    const key = splits.first();
    const val = splits.next() orelse "<unknown>";

    return .{
        .key = try alloc.dupe(u8, key),
        .val = try alloc.dupe(u8, val),
    };
}

pub const VorbisComment = struct {
    vendor_string: []u8,
    tags: std.StringHashMap([]const u8),

    pub const FilterIterator = struct {
        vc: *const VorbisComment,
        filter: StringArrayList,
        index: usize,

        pub fn next(self: *FilterIterator) ?VorbisTag {
            if (self.index < self.filter.count()) {
                const filter_key = self.filter.slices.items[self.index];
                var upper_key_buf: [100]u8 = undefined;
                const upper_key = std.ascii.upperString(&upper_key_buf, filter_key);
                const value = self.vc.tags.get(upper_key);
                self.index += 1;
                if (value) |v| {
                    return .{
                        .key = filter_key,
                        .val = v,
                    };
                }
            }
            return null;
        }
    };

    pub fn deinit(vc: VorbisComment, alloc: std.mem.Allocator) void {
        alloc.free(vc.vendor_string);

        var iter = vc.tags.iterator();
        while (iter.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            alloc.free(entry.value_ptr.*);
        }

        var tags = vc.tags;
        tags.clearAndFree();
        tags.deinit();
    }

    pub fn json(vc: *const VorbisComment, alloc: std.mem.Allocator) ![]u8 {
        return try fmt.formatJSON(alloc, vc.tags, null);
    }

    pub fn raw_text(vc: *const VorbisComment, alloc: std.mem.Allocator) ![]u8 {
        return try fmt.formatRaw(alloc, vc.tags, null);
    }

    pub fn pretty(vc: *const VorbisComment, alloc: std.mem.Allocator) ![]u8 {
        return try fmt.formatPretty(alloc, vc.tags, null);
    }

    pub fn filterIter(vc: *const VorbisComment, filter: StringArrayList) FilterIterator {
        return FilterIterator{
            .vc = vc,
            .filter = filter,
            .index = 0,
        };
    }
};

// NOTE: maybe error if length of input is incorrect?
/// returns if bytes are equal to vorbis
/// signature bytes. returns false if
/// bytes.len != SIGNATURE.len
pub fn signature(bytes: []u8) bool {
    if (bytes.len != SIGNATURE.len) {
        return false;
    }
    return std.mem.eql(u8, bytes, &SIGNATURE);
}
