const std = @import("std");

pub fn sliceAsT(comptime T: type, slice: []u8) void {
   std.debug.print("!!! {any}\n", .{@sizeOf(T)}); 

}
