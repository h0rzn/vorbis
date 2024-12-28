const std = @import("std");

pub const StringArrayList = SliceArrayList(u8);

fn SliceArrayList(T: type) type {
    return struct {
        const Self = @This();
        slices: std.ArrayList([]const T),
        // count: usize,
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

        pub fn put(self: *Self, block: []const T) !void {
            const owned_slice = try self.alloc.dupe(u8, block);
            // defer self.alloc.free(owned_slice);
            try self.slices.append(owned_slice);
            // self.count = self.count + 1;
        }

        pub fn count(self: *const Self) usize {
            return self.slices.items.len;
        }

        pub fn iter(self: *const Self) Iterator {
            return Iterator{
                .slices = &self.slices,
                .index = 0,
            };
        }
    };
}
