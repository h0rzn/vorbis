const std = @import("std");
const fs = std.fs;
const audio_file = @import("audio_file.zig");
const cli = @import("cli.zig");
const flac = @import("flac.zig");
const ogg = @import("ogg.zig");
const fmt = @import("fmt.zig");
const file_reader = @import("reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const opts = cli.readOpts(allocator) catch |err| {
        std.debug.print("Error reading options: {}\n", .{err});

        return;
    };
    defer allocator.destroy(opts);

    const file: fs.File = audio_file.readFile(opts.f_name) catch |err| {
        std.debug.print("Error reading file: {}\n", .{err});

        return;
    };

    var reader = try file_reader.Reader.init(allocator, file);
    const audio_type = try audio_file.readMarker(&reader);
    switch (audio_type) {
        .OGG => {
            const vorbis_comment = try ogg.readOGG(allocator, &reader);
            if (vorbis_comment) |comment| {
                defer comment.deinit(allocator);

                std.debug.print("{any}", .{vorbis_comment});
            }
        },
        .FLAC => {
            const vorbis_comment = try flac.readFLAC(allocator, &reader);
            if (vorbis_comment) |comment| {
                defer comment.deinit(allocator);

                const comment_fmt_raw = try comment.raw_text(allocator, "=");
                defer allocator.free(comment_fmt_raw);
                std.debug.print("{s}", .{comment_fmt_raw});

                std.debug.print("\n", .{});

                const comment_fmt_json = try comment.json(allocator);
                defer allocator.free(comment_fmt_json);
                std.debug.print("{s}", .{comment_fmt_json});

                std.debug.print("\n\n", .{});

                const comment_fmt_pretty = try comment.pretty(allocator);
                std.debug.print("{s}\n", .{comment_fmt_pretty});
                allocator.free(comment_fmt_pretty);
            }
        },
        else => std.log.err("illegal file marker", .{}),
    }
}
