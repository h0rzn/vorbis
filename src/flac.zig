const std = @import("std");
const fs = std.fs;
const vorbis = @import("vorbis.zig");
const cli = @import("cli.zig");
const Reader = @import("reader.zig").Reader;

pub const SIGNATURE = [4]u8{ 0x66, 0x4c, 0x61, 0x43 }; // ASCII: fLaC

// TODO: up this
const MAX_BLOCK_LEN = 200000;

pub const FlacError = error{
    OversizedBlock,
    VorbisMissing,
};

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

const MetadataBlockHeader = enum { Streaminfo, Padding, Application, Seektable, VorbisComment, CueSheet, Picture, Ignore };

const BlockHeader = struct {
    type: MetadataBlockHeader,
    last: bool = false,
    len: u24,
};

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
