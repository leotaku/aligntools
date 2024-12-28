const std = @import("std");
const Hash = std.hash.XxHash32;

const keys: [10][]const u8 = .{
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

fn bufSetGreaterThan(_: void, lhs: std.BufSet, rhs: std.BufSet) bool {
    return lhs.count() > rhs.count();
}

fn generatePerfectHash(allocator: std.mem.Allocator) !void {
    const r = std.math.sqrt(keys.len);
    const buckets = try allocator.alloc(std.BufSet, r);
    defer allocator.free(buckets);
    for (buckets) |*bucket| {
        bucket.* = std.BufSet.init(allocator);
    }

    for (keys) |key| {
        const i = Hash.hash(0, key) % r;
        try buckets[i].insert(key);
    }

    std.mem.sort(std.BufSet, buckets, {}, bufSetGreaterThan);

    var E = try allocator.alloc(usize, buckets.len);
    @memset(E, 0);
    defer allocator.free(E);

    var T = try allocator.alloc(usize, keys.len * 3);
    @memset(T, 0);
    defer allocator.free(T);

    for (0.., buckets) |B_i, B| {
        l_loop: for (1..1000) |l| {
            var K = try allocator.alloc(u32, keys.len);
            @memset(K, 0);
            defer allocator.free(K);
            var B_iter = B.iterator();
            while (B_iter.next()) |elem| {
                var D = Hash.init(0);
                D.update(elem.*);
                D.update(&[_]u8{@intCast(l)});
                const hash = D.final();

                std.debug.print(". {d} {d}\n", .{ hash % K.len, hash });
                if (T[hash % T.len] != 0) {
                    std.debug.print(": retry\n", .{});
                    continue :l_loop;
                }
                K[hash % K.len] = hash;
            }
            std.debug.print("--- {d} {d} {d}\n", .{
                B.count(),
                K.len,
                std.mem.count(u32, K, &.{0}),
            });

            if (!std.mem.containsAtLeast(u32, K, K.len - B.count() + 1, &.{0})) {
                E[B_i] = l;
                for (K) |j| {
                    T[j % T.len] = 1;
                }
                break;
            }
        }
        std.debug.print(": {d}\n", .{B.count()});
    }

    for (buckets) |*bucket| {
        bucket.deinit();
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    try generatePerfectHash(allocator);
}
