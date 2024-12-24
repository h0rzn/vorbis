const std = @import("std");
const fs = std.fs;
const audio_file = @import("audio_file.zig");
const cli = @import("cli.zig");
const flac = @import("flac.zig");
const ogg = @import("ogg.zig");
const fmt = @import("fmt.zig");
const file_reader = @import("reader.zig");
const vorbis = @import("vorbis.zig");
const Reader = @import("reader.zig").Reader;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const opts = cli.parse(allocator) catch |err| {
        cli.printErr(err);
        return;
    };

    defer allocator.destroy(opts);

    const file: fs.File = audio_file.readFile(opts.f_name) catch |err| {
        cli.printErr(err);
        return;
    };

    var reader = try file_reader.Reader.init(allocator, file);
    const audio_type = audio_file.readMarker(&reader) catch |err| {
        cli.printErr(err);
        return;
    };

    const vorbis_comment = readComment(allocator, &reader, audio_type) catch |err| {
        cli.printErr(err);
        return;
    };

    defer vorbis_comment.deinit(allocator);

    switch (opts.out_mode) {
        cli.OutMode.RawText => {
            const comment_fmt_raw = try vorbis_comment.raw_text(allocator, "=");
            defer allocator.free(comment_fmt_raw);
            cli.println(comment_fmt_raw);
        },
        cli.OutMode.Pretty => {
            const comment_fmt_pretty = try vorbis_comment.pretty(allocator);
            defer allocator.free(comment_fmt_pretty);
            cli.println(comment_fmt_pretty);
        },
        cli.OutMode.Json => {
            const comment_fmt_json = try vorbis_comment.json(allocator);
            defer allocator.free(comment_fmt_json);
            cli.println(comment_fmt_json);
        },
    }
}

fn readComment(alloc: std.mem.Allocator, reader: *Reader, audio_type: audio_file.AudioFileType) !vorbis.VorbisComment {
    return switch (audio_type) {
        .OGG => try ogg.readOGG(alloc, reader),
        .FLAC => try flac.readFLAC(alloc, reader),
    };
}
