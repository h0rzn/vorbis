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
    Pretty,
    /// Json is unformatted string output in json format
    Json,
    /// RawText is the default mode. Format is KV with "=" delim
    RawText,
};

pub const OptsError = error{
    // NoArgs is returned if no arguments have been passed
    NoArgs,
    // InvalidOutMode is returned if outmode has illegal value
    // or is missing
    InvalidOutMode,
    // NoFilename is returned if filename is missing
    NoFilename,
};

/// parse parses the cli input params using zig-clap.
/// This function returns Opts containing the values
/// for available flags.
pub fn parse(alloc: std.mem.Allocator) !*Opts {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help.
        \\-i, --input <STR>     Specify audio file name.
        \\-g, --get <STR>       Get Comment field by name.
        \\-f, --format <STR>    Specifiy output format.
    );

    const parsers = comptime .{ .STR = clap.parsers.string };

    const res = try clap.parse(clap.Help, &params, parsers, .{
        .allocator = alloc,
    });

    var opts = try alloc.create(Opts);
    errdefer {
        alloc.destroy(opts);
    }
    var param_count: u8 = 0;

    if (res.args.input) |filename| {
        param_count += 1;
        opts.f_name = filename;
    } else {
        return OptsError.NoFilename;
    }

    if (res.args.get) |keys| {
        var filter = util.StringArrayList.init(alloc);
        errdefer {
            filter.deinit();
        }
        param_count += 1;

        var key_iter = std.mem.splitSequence(u8, keys, ",");
        while (key_iter.next()) |key| {
            if (key.len > 0) {
                try filter.put(key);
            }
        }
        opts.filter = filter;
    } else {
        opts.filter = null;
    }

    if (res.args.format) |format| {
        param_count += 1;
        opts.out_mode = try readOutMode(format);
    } else {
        opts.out_mode = OutMode.RawText;
    }

    if (param_count == 0) return OptsError.NoArgs;

    return opts;
}

/// readOutMode maps out_mode to a OutMode field
fn readOutMode(out_mode: []const u8) OptsError!OutMode {
    if (std.mem.eql(u8, out_mode, "pretty")) return .Pretty;
    if (std.mem.eql(u8, out_mode, "json")) return .Json;
    if (std.mem.eql(u8, out_mode, "raw")) return .RawText;

    return OptsError.InvalidOutMode;
}

/// println prints out a value with following linebreak.
/// if value is []u8 formats as string otherwise as any
pub fn println(value: anytype) void {
    std.Progress.lockStdErr();
    defer std.Progress.unlockStdErr();
    const stdout = io.getStdOut().writer();

    const templ = if (@TypeOf(value) == []u8) "{s}\n" else "{any}\n";
    nosuspend stdout.print(templ, .{value}) catch return;
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
