const std = @import("std");

pub const Reader = struct {
    alloc: std.mem.Allocator,
    file: std.fs.File,
    buf_reader: std.io.BufferedReader(4096, std.fs.File.Reader),

    pub fn init(alloc: std.mem.Allocator, file: std.fs.File) !Reader {
        return .{
            .alloc = alloc,
            .file = file,
            .buf_reader = std.io.bufferedReader(file.reader()),
        };
    }

    pub fn readOne(r: *Reader) !u8 {
        var bit: [1]u8 = undefined;
        const read_count = try r.buf_reader.read(&bit);

        return if (read_count == 1) bit[0] else error.UnexpectedOEF;
    }

    pub fn readN(r: *Reader, comptime n: usize) ![n]u8 {
        var mem: [n]u8 = undefined;
        const bytes_read = try r.buf_reader.read(&mem);
        if (bytes_read != n) {
            return error.UnexpectedEOF;
        }

        return mem;
    }

    pub fn readAsT(r: *Reader, comptime T: type) !T {
        const bytes = try r.readN(@sizeOf(T));

        return std.mem.readInt(T, &bytes, .little);
    }

    pub fn readNSlice(r: *Reader, allocator: std.mem.Allocator, n: usize) ![]u8 {
        const buffer = try allocator.alloc(u8, n);
        errdefer allocator.free(buffer);

        const bytes_read = try r.buf_reader.read(buffer);
        if (bytes_read < n) {
            allocator.free(buffer);
            return error.UnexpectedEOF;
        }

        return buffer;
    }

    pub fn skipN(r: *Reader, n: u64) !void {
        try r.buf_reader.reader().skipBytes(n, .{});
    }

    // TODO: implement
    pub fn close(r: *Reader) !void {
        _ = r;
    }
};
