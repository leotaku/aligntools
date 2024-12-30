const std = @import("std");
const PerfectHash = @import("perfect_hash.zig").PerfectHash;

const example_keys: [10][]const u8 = .{
    "foo",
    "bar",
    "baz",
    "boo",
    "bat",
    "bart",
    "fart",
    "laissez-faire",
    "miscellaneous",
    "robot",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var ph = try PerfectHash.build(allocator, &example_keys);
    defer ph.deinit();

    for (example_keys) |key| {
        std.debug.print("{s} => {d}\n", .{ key, ph.hash(key) });
    }
}
