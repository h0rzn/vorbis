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

const util = @import("util.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const opts = cli.parse(allocator) catch |err| {
        cli.printErr(err);
        return;
    };
    defer {
        if (opts.filter) |*filter| {
            filter.deinit();
        }
        allocator.destroy(opts);
    }

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

    output(allocator, &vorbis_comment, opts) catch |err| {
        cli.printErr(err);
    };
}

fn readComment(alloc: std.mem.Allocator, reader: *Reader, audio_type: audio_file.AudioFileType) !vorbis.VorbisComment {
    return switch (audio_type) {
        .OGG => try ogg.readOGG(alloc, reader),
        .FLAC => try flac.readFLAC(alloc, reader),
    };
}

fn output(alloc: std.mem.Allocator, vorbis_comment: *const vorbis.VorbisComment, opts: *cli.Opts) !void {
    if (opts.filter) |filter| {
        outputFiltered(alloc, vorbis_comment, filter) catch |err| {
            cli.printErr(err);
        };
    } else {
        outputFull(alloc, vorbis_comment, opts) catch |err| {
            cli.printErr(err);
        };
    }
}

/// outputFiltered outputs a single vorbis field based on key defined
/// in cli.Opts.key. For now this output ignores the --format switch
fn outputFiltered(alloc: std.mem.Allocator, vorbis_comment: *const vorbis.VorbisComment, filter: util.StringArrayList) !void {
    const json = try fmt.formatJSON(alloc, vorbis_comment.tags, filter);
    defer alloc.free(json);
    cli.println(json);
}

// outputFull outputs the complete vorbis set in the desired format as
// defined in cli.Opts.out_mode
fn outputFull(alloc: std.mem.Allocator, vorbis_comment: *const vorbis.VorbisComment, opts: *cli.Opts) !void {
    switch (opts.out_mode) {
        cli.OutMode.RawText => {
            const comment_fmt_raw = try vorbis_comment.raw_text(alloc, "=");
            defer alloc.free(comment_fmt_raw);
            cli.println(comment_fmt_raw);
        },
        cli.OutMode.Pretty => {
            const comment_fmt_pretty = try vorbis_comment.pretty(alloc);
            defer alloc.free(comment_fmt_pretty);
            cli.println(comment_fmt_pretty);
        },
        cli.OutMode.Json => {
            const comment_fmt_json = try vorbis_comment.json(alloc);
            defer alloc.free(comment_fmt_json);
            cli.println(comment_fmt_json);
        },
    }
}
