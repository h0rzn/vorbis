const std = @import("std");

/// Reader provides reader utility functions
/// for a std.fs.File. It wraps a
/// std.io.BufferedReader with buffersize 4096.
/// Read operations can be mixed but advance the reader
/// irreversably.
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

    /// readOne reads a single byte and returns a u8. If reading fails
    /// it errors. If bytes read is not exactly 1, UnexpectedOEF is returned.
    pub fn readOne(r: *Reader) !u8 {
        var byte: [1]u8 = undefined;
        const read_count = try r.buf_reader.read(&byte);

        return if (read_count == 1) byte[0] else error.UnexpectedOEF;
    }

    /// readN reads n bytes. Returns read error or UnexpectedEOF when failing.
    pub fn readN(r: *Reader, comptime n: usize) ![n]u8 {
        var mem: [n]u8 = undefined;
        const bytes_read = try r.buf_reader.read(&mem);
        if (bytes_read != n) {
            return error.UnexpectedEOF;
        }

        return mem;
    }

    /// readNSlice reads dynamic amount of bytes n as slice. Returns read error
    /// or UnexpectedEOF when failing.
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

    /// readAsT reads @sizeOf(T) bytes and interpretes them as type T.
    pub fn readAsT(r: *Reader, comptime T: type) !T {
        const bytes = try r.readN(@sizeOf(T));

        return std.mem.readInt(T, &bytes, .little);
    }

    /// skipN skips the next n bytes.
    pub fn skipN(r: *Reader, n: u64) !void {
        try r.buf_reader.reader().skipBytes(n, .{});
    }
};
