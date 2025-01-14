const std = @import("std");
const testing = std.testing;
const PerfectHash = @import("perfect_hash.zig").PerfectHash;
const hirschberg_gotoh = @import("hirschberg_gotoh.zig");

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

test "test perfect hash" {
    var ph = try PerfectHash.build(testing.allocator, &example_keys);
    defer ph.deinit();

    for (example_keys) |key| {
        std.debug.print("{s} => {d}\n", .{ key, ph.hash(key) });
    }
}

test "test cost" {
    const A = "dddddadcd";
    const B = "0adcd";

    const cost = try hirschberg_gotoh.cost(testing.allocator, A, B);
    std.debug.print("cost: {d}\n", .{cost});

    const edits = try hirschberg_gotoh.transform(testing.allocator, A, B);
    defer edits.deinit();
    try hirschberg_gotoh.writeEdits(std.io.getStdErr().writer(), edits.items);
}
