const std = @import("std");
const io = std.io;
const clap = @import("clap");
const fmt = @import("fmt.zig");
const util = @import("util.zig");

/// Opts stores available cli input values (params)
pub const Opts = struct {
    out_mode: OutMode,
    f_name: []const u8,
    filter: ?util.StringArrayList,
};

/// OutMode represents output modes.
pub const OutMode = enum {
    /// Pretty is color formatted output
    pretty,
    /// Json is unformatted string output in json format
    json,
    /// RawText is the default mode. Format is KV with "=" delim
    rawText,
};

pub const OptsError = error{
    // InvalidOutMode is returned if outmode has illegal value
    // or is missing
    InvalidOutMode,
    // NoFilename is returned if filename is missing
    NoFilename,
    // NOOPParseError indicates an error when clap errors when parsing
    // input params. 'NOOP' means that error output is handled by the parse()
    // so the function receiving the error must not handle it
    NOOPParseError,
} || std.mem.Allocator.Error;

const params = clap.parseParamsComptime(
    \\ -h, --help                       Show usage help and exit.
    \\ -v, --version                    Show version information and exit.
    \\ <file>                           Specify one or more input files. Supports both .ogg and .flac.
    \\ -o, --output-format <format>     Specify output format. Supported formats: raw, pretty, json
    \\ -f, --fields <keys>              Specify fields to display by key. Use a comma separated list for multiple values.
);

const parsers = .{
    .file = clap.parsers.string,
    .format = clap.parsers.string,
    .keys = clap.parsers.string,
    .OUT_MODE = clap.parsers.enumeration(OutMode),
};

pub var diag = clap.Diagnostic{};

/// parse parses the cli input params using zig-clap.
/// This function returns Opts containing the values
/// for available flags.
pub fn parse(alloc: std.mem.Allocator) !OptsResult {
    const res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return OptsError.NOOPParseError;
    };
    defer res.deinit();

    return try createOpts(alloc, res);
}

pub const OptsResult = union(enum) {
    version: void,
    help: void,
    output: *Opts,
};

fn createOpts(alloc: std.mem.Allocator, result: clap.Result(clap.Help, &params, parsers)) OptsError!OptsResult {
    if (result.args.help != 0) {
        return .help;
    }

    if (result.args.version != 0) {
        return .version;
    }

    var opts = try alloc.create(Opts);
    errdefer {
        alloc.destroy(opts);
    }

    const filenames = result.positionals;
    if (filenames.len == 0) {
        return OptsError.NoFilename;
    }
    for (0..filenames.len, filenames) |i, filename| {
        if (i == 0) {
            opts.f_name = filename;
        } else {
            printFmt("{s}Warning{s}: multi file support not implemented, skipping: arg {s}\n", .{ fmt.Colors.yellow, fmt.Colors.reset, filename });
        }
    }

    if (result.args.@"output-format") |format| {
        opts.out_mode = try readOutMode(format);
    }

    if (result.args.fields) |fields| {
        var filter = util.StringArrayList.init(alloc);
        errdefer filter.deinit();

        var key_iter = std.mem.splitSequence(u8, fields, ",");
        while (key_iter.next()) |key| {
            if (key.len > 0) {
                var upper_key_buf: [100]u8 = undefined;
                const upper_key = std.ascii.upperString(&upper_key_buf, key);
                try filter.put(upper_key);
            }
        }
        opts.filter = filter;
    } else {
        opts.filter = null;
    }

    return .{ .output = opts };
}

/// readOutMode maps out_mode to a OutMode field
fn readOutMode(out_mode: []const u8) OptsError!OutMode {
    if (std.mem.eql(u8, out_mode, "pretty")) return .pretty;
    if (std.mem.eql(u8, out_mode, "json")) return .json;
    if (std.mem.eql(u8, out_mode, "raw")) return .rawText;

    return OptsError.InvalidOutMode;
}

pub fn help() !void {
    try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
}

pub fn version() void {
    std.debug.print("<< version info here >>\n", .{});
}

/// println prints out a value with following linebreak.
/// if value is []u8 formats as string otherwise as any
pub fn println(value: anytype) void {
    std.Progress.lockStdErr();
    defer std.Progress.unlockStdErr();
    const stdout = io.getStdOut().writer();

    if (@TypeOf(value) == []u8) {
        if (value.len == 0) {
            return;
        }

        nosuspend stdout.print("{s}\n", .{value}) catch return;
    } else {
        nosuspend stdout.print("{any}\n", .{value}) catch return;
    }
}

/// printFmt prints out args with format template format.
/// This function acts like std.debug.print
pub fn printFmt(comptime format: []const u8, args: anytype) void {
    std.Progress.lockStdErr();
    defer std.Progress.unlockStdErr();
    const stdout = io.getStdOut().writer();
    nosuspend stdout.print(format, args) catch return;
}

/// printErr prints formatted output containing the error name
pub fn printErr(err: anyerror) void {
    printFmt("{s}Error: {s}{s}\n", .{
        fmt.Colors.red,
        fmt.Colors.reset,
        @errorName(err),
    });
}

/// printAsErr works like std.debug.print or cli.printFmt
/// but also applies formatting as if the passed message
/// was an error
pub fn printAsErr(comptime message_format: []const u8, args: anytype) void {
    printFmt("{s}Error: {s}" ++ message_format ++ "\n", .{
        fmt.Colors.red,
        fmt.Colors.reset,
    } ++ args);
}

/// printHexSlice prints slice items in hex format
pub fn printHexSlice(slice: []const u8) void {
    for (slice) |item| {
        printFmt("0x{x} ", .{item});
    }
}

/// printHexSlice prints array items in hex format
pub fn printHexArray(comptime n: usize, array: [n]u8) void {
    printHexSlice(&array);
}
