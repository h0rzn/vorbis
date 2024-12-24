const std = @import("std");
const io = std.io;
const clap = @import("clap");

const fmt = @import("fmt.zig");

pub const CliOpts = struct {
    out_mode: OutMode,
    f_name: []const u8,
};

pub const OutMode = enum {
    Pretty,
    Json,
    RawText,
};

pub const CliOptsError = error{ NoArgs, InvalidOutMode, NoFilename };

pub fn parse(alloc: std.mem.Allocator) !*CliOpts {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help.
        \\-i, --input <STR>     Specify audio file name.
        \\-f, --format <STR>    Specifiy output format.
    );

    const parsers = comptime .{ .STR = clap.parsers.string };

    const res = try clap.parse(clap.Help, &params, parsers, .{
        .allocator = alloc,
    });

    const opts = try alloc.create(CliOpts);
    errdefer alloc.destroy(opts);
    var param_count: u8 = 0;

    if (res.args.input) |filename| {
        param_count += 1;
        opts.f_name = filename;
    } else {
        return CliOptsError.NoFilename;
    }

    if (res.args.format) |format| {
        param_count += 1;
        opts.out_mode = try readOutMode(format);
    } else {
        opts.out_mode = OutMode.RawText;
    }

    if (param_count == 0) return CliOptsError.NoArgs;

    return opts;
}

fn readOutMode(out_mode: []const u8) CliOptsError!OutMode {
    if (std.mem.eql(u8, out_mode, "pretty")) return .Pretty;
    if (std.mem.eql(u8, out_mode, "json")) return .Json;
    if (std.mem.eql(u8, out_mode, "raw")) return .RawText;

    return CliOptsError.InvalidOutMode;
}

pub fn println(args: anytype) void {
    // std.Progress.lockStdErr();
    // defer std.Progress.unlockStdErr();
    const stdout = io.getStdOut().writer();
    nosuspend stdout.print("{s}\n", args) catch return;
}

pub fn printFmt(comptime format: []const u8, args: anytype) void {
    // std.Progress.lockStdErr();
    // defer std.Progress.unlockStdErr();
    const stdout = io.getStdOut().writer();
    nosuspend stdout.print(format, args) catch return;
}

pub fn printErr(err: anyerror) void {
    printFmt("{s}Error: {s}{s}\n", .{
        fmt.Colors.red,
        fmt.Colors.reset,
        @errorName(err),
    });
}
