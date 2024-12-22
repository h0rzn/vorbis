const std = @import("std");
const io = std.io;

pub const CliOpts = struct {
    out_mode: OutMode = null,
    f_name: []const u8 = null,
};

pub const OutMode = enum { Pretty, Json, RawText };

pub const CliOptsError = error{ NoArgs, InvalidOutMode, NoFilename };

pub fn readOpts(alloc: std.mem.Allocator) !*CliOpts {
    var args = std.process.args();

    const opts = try alloc.create(CliOpts);
    errdefer alloc.destroy(opts);

    var args_count: u8 = 0;
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            const field = arg[1..];
            if (args.next()) |value| {
                try setOption(opts, field, value);
                args_count += 1;
            } else {
                std.debug.print("Error reading flag value for {s}\n", .{field});
                break;
            }
        }
    }

    if (args_count == 0) {
        return CliOptsError.NoArgs;
    }

    if (opts.f_name.len == 0) {
        return CliOptsError.NoFilename;
    }

    return opts;
}

fn setOption(opts: *CliOpts, field_name: []const u8, value: []const u8) !void {
    if (std.mem.eql(u8, field_name, "i")) {
        opts.f_name = value;
    } else if (std.mem.eql(u8, field_name, "f")) {
        opts.out_mode = try readOutMode(value);
    } else {
        std.log.warn("unkown option '{s'}'", .{field_name});
    }
}

fn readOutMode(out_mode: []const u8) CliOptsError!OutMode {
    if (std.mem.eql(u8, out_mode, "pretty")) return .Pretty;
    if (std.mem.eql(u8, out_mode, "json")) return .Json;
    if (std.mem.eql(u8, out_mode, "raw")) return .RawText;
    return CliOptsError.InvalidOutMode;
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    // std.Progress.lockStdErr();
    // defer std.Progress.unlockStdErr();
    const stdout = io.getStdOut().writer();
    nosuspend stdout.print(fmt, args) catch return;
}
