const std = @import("std");
const fs = std.fs;
const flac = @import("flac.zig");
const ogg = @import("ogg.zig");
const vorbis = @import("vorbis.zig");
const Reader = @import("reader.zig").Reader;

pub const AudioFileType = enum { FLAC, OGG };

pub const AudioFileError = error{MissingSignature};

/// readFile reads file contents of a file based
/// on file_path.
pub fn readFile(file_path: []const u8) !fs.File {
    var path_buffer: [fs.max_path_bytes]u8 = undefined;
    const path = try fs.realpath(file_path, &path_buffer);
    const file = try std.fs.openFileAbsolute(path, .{});

    return file;
}

/// readMarker attempts to identify a audio file by detecting
/// a signature. A *reader.Reader is expected as the source of file data.
pub fn readMarker(reader: *Reader) !AudioFileType {
    const signature: [4]u8 = try reader.readN(4);
    if (std.mem.eql(u8, &signature, &flac.SIGNATURE)) return AudioFileType.FLAC;

    if (std.mem.eql(u8, &signature, &ogg.SIGNATURE)) return AudioFileType.OGG;

    return AudioFileError.MissingSignature;
}

/// readComment runs a read function based on audio_type.
/// Returns VorbisComment or error.
pub fn readComment(alloc: std.mem.Allocator, reader: *Reader, audio_type: AudioFileType) !vorbis.VorbisComment {
    return switch (audio_type) {
        .OGG => try ogg.readOGG(alloc, reader),
        .FLAC => try flac.readFLAC(alloc, reader),
    };
}
