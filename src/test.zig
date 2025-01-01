const std = @import("std");
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

test "old main" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var ph = try PerfectHash.build(allocator, &example_keys);
    defer ph.deinit();

    for (example_keys) |key| {
        std.debug.print("{s} => {d}\n", .{ key, ph.hash(key) });
    }

    const A = "dddddadcd";
    const B = "0adcd";

    const cost = try hirschberg_gotoh.cost(allocator, A, B);
    std.debug.print("cost: {d}\n", .{cost});

    const edits = try hirschberg_gotoh.transform(allocator, A, B);
    defer edits.deinit();
    try hirschberg_gotoh.write_edits(std.io.getStdErr().writer(), edits.items);
}

// test "bench" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     defer std.debug.assert(gpa.deinit() == .ok);

//     const start = try std.time.Instant.now();
//     const edits_ = try hirschberg_gotoh.transform(allocator, "a" ** (1 << 18), "b" ** (1 << 18));
//     defer edits_.deinit();
//     std.debug.print("Elapsed: {s}\n", .{std.fmt.fmtDuration((try std.time.Instant.now()).since(start))});
// }
