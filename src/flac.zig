const std = @import("std");
const fs = std.fs;
const vorbis = @import("vorbis.zig");
const cli = @import("cli.zig");
const Reader = @import("reader.zig").Reader;

/// SIGNATURE are the "magic bytes" that mark flac.
/// ASCII: flaC
pub const SIGNATURE = [4]u8{ 0x66, 0x4c, 0x61, 0x43 };

/// MAX_BLOCK_LEN describes the maximum length of a flac block
const MAX_BLOCK_LEN = 200000;

pub const FlacError = error{
    /// OversizedBlock is returned if block size is > MAX_BLOCK_LEN
    OversizedBlock,
    /// VorbisMissing is returned when vorbis signature was
    /// expected but could not be found
    VorbisMissing,
};

/// readFLAC uses the audio file reader to parse a VorbisComment.
pub fn readFLAC(alloc: std.mem.Allocator, reader: *Reader) !vorbis.VorbisComment {
    while (true) {
        const block_header_bytes = try reader.readN(4);
        const block_header = try parseMetadataBlockHeader(block_header_bytes);
        if (block_header.len > MAX_BLOCK_LEN) {
            cli.printAsErr("Block size for {} ({}) exceeds max block len {}\n", .{ block_header.type, block_header.len, MAX_BLOCK_LEN });

            return FlacError.OversizedBlock;
        }
        if (block_header.type == MetadataBlockHeader.VorbisComment) {
            const vorbis_bytes = try reader.readNSlice(alloc, block_header.len);
            defer alloc.free(vorbis_bytes);
            const vorbis_comment = try vorbis.parseVorbisComment(alloc, vorbis_bytes);

            return vorbis_comment;
        }

        try reader.skipN(block_header.len);
        if (block_header.last) {
            break;
        }
    }

    return FlacError.VorbisMissing;
}

/// MetadataBlockHeader stores possible Block Types
const MetadataBlockHeader = enum { Streaminfo, Padding, Application, Seektable, VorbisComment, CueSheet, Picture, Ignore };

/// BlockHeader is the header for a block
const BlockHeader = struct {
    type: MetadataBlockHeader,
    last: bool = false,
    len: u24,
};

/// parseMetadataBlockHeader parses a BlockHeader from
/// given block header bytes
fn parseMetadataBlockHeader(header: [4]u8) !BlockHeader {
    const is_last = (header[0] & 0x80) != 0;
    const block_type = @as(u7, @truncate(header[0] & 0x7F));
    const block_length = @as(u24, header[1]) << 16 | @as(u24, header[2]) << 8 | header[3];

    return .{
        .type = @enumFromInt(block_type),
        .last = is_last,
        .len = block_length,
    };
}
