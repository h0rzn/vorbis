const std = @import("std");
const fs = std.fs;
const fmt = @import("fmt.zig");
const Reader = @import("reader.zig").Reader;
const StringArrayList = @import("util.zig").StringArrayList;

/// SIGNATURE are the "magic bytes" that mark vorbis.
/// ASCII: vorbis
pub const SIGNATURE = [6]u8{ 0x76, 0x6f, 0x72, 0x62, 0x69, 0x73 };

pub const VorbisError = error{
    /// PacketBadLength is returned if a packet is smaller or
    /// equal to the vorbis signature so the packet can't
    /// contain any (useful) data
    PacketBadLength,
};

/// parseVorbisComment parses a vorbis block and returns VorbisComment
/// or error. Block can be a block read from OGG or FLAC files.
pub fn parseVorbisComment(alloc: std.mem.Allocator, block: []u8) !VorbisComment {
    if (block.len <= 4) return VorbisError.PacketBadLength;

    var stream = std.io.fixedBufferStream(block);
    var stream_reader = stream.reader();

    const vendor_length = try stream_reader.readInt(u32, std.builtin.Endian.little);
    const vendor_string = try alloc.alloc(u8, vendor_length);
    errdefer alloc.free(vendor_string);
    try stream_reader.readNoEof(vendor_string);

    const user_comment_list_length = try stream_reader.readInt(u32, std.builtin.Endian.little);
    var tags = std.StringHashMap([]const u8).init(alloc);
    errdefer {
        var iter = tags.iterator();
        while (iter.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            alloc.free(entry.value_ptr.*);
        }
        tags.deinit();
    }
    var comment_index: i32 = 0;
    while (comment_index < user_comment_list_length) : (comment_index += 1) {
        const comment_length = try stream_reader.readInt(u32, std.builtin.Endian.little);

        const comment = try alloc.alloc(u8, comment_length);
        defer alloc.free(comment);

        try stream_reader.readNoEof(comment);
        const vorbis_tag = try split(alloc, comment);

        try tags.put(vorbis_tag.key, vorbis_tag.val);
    }

    return .{
        .vendor_string = vendor_string,
        .tags = tags,
    };
}

/// VorbisTag is a simple KV container for tags.
/// Example: ARTIST=artist_name
pub const VorbisTag = struct {
    key: []const u8,
    val: []const u8,
};

/// split creates a VorbisTag or error from a vorbis KV string,
/// after '='. Expects the key before delimiter to exist. If no value
/// is found, '<unkown>' is used as value.
fn split(alloc: std.mem.Allocator, kv_string: []const u8) !VorbisTag {
    var splits = std.mem.split(u8, kv_string, "=");
    const key = splits.first();
    const val = splits.next() orelse "<unknown>";

    return .{
        .key = try alloc.dupe(u8, key),
        .val = try alloc.dupe(u8, val),
    };
}

/// VorbisComment stores a vorbis comment.
/// Tags can be accessed with .tags or using
/// the filtered iterator. This struct also
/// provides formatting functions for stored tags.
pub const VorbisComment = struct {
    vendor_string: []u8,
    tags: std.StringHashMap([]const u8),

    /// FilterIterator provides a iterator
    /// that returns items based on the keys
    /// stored in .filter
    pub const FilterIterator = struct {
        vc: *const VorbisComment,
        filter: StringArrayList,
        index: usize,

        /// next is the iterator function to iter over
        /// tags in VorbisComment that match the given filters based on key
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
