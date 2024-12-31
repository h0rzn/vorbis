const std = @import("std");

pub const StringArrayList = SliceArrayList(u8);

/// SliceArrayList is an ArrayList([]const T).
/// Provides an Iterator to iterate items by
/// returning []const T. Items can be added
/// by calling 'put', but removing them is not
/// supported.
fn SliceArrayList(T: type) type {
    return struct {
        const Self = @This();
        slices: std.ArrayList([]const T),
        alloc: std.mem.Allocator,

        pub const Iterator = struct {
            slices: *const std.ArrayList([]const T),
            index: usize,

            pub fn next(self: *Iterator) ?[]const T {
                if (self.index < self.slices.items.len) {
                    const item = self
                        .slices.items[self.index];
                    self.index += 1;
                    return item;
                }
                return null;
            }
        };

        pub fn init(alloc: std.mem.Allocator) Self {
            return Self{
                .slices = std.ArrayList([]const T).init(alloc),
                .alloc = alloc,
            };
        }

        pub fn deinit(self: Self) void {
            for (self.slices.items) |item| {
                self.alloc.free(item);
            }
            self.slices.deinit();
        }

        /// put appends a block to the internal ArrayList.
        /// Block is duped and appended to the internal ArrayList.
        /// Memory is managed internally.
        pub fn put(self: *Self, block: []const T) !void {
            const owned_slice = try self.alloc.dupe(u8, block);
            try self.slices.append(owned_slice);
        }

        /// count returns the amount of blocks stored in the
        /// internal ArrayList
        pub fn count(self: *const Self) usize {
            return self.slices.items.len;
        }

        /// iter returns the iterator for stored blocks.
        pub fn iter(self: *const Self) Iterator {
            return Iterator{
                .slices = &self.slices,
                .index = 0,
            };
        }
    };
}
