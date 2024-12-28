const std = @import("std");
const Hash = std.hash.XxHash32;

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

fn bufSetGreaterThan(_: void, lhs: std.BufSet, rhs: std.BufSet) bool {
    return lhs.count() > rhs.count();
}

fn generatePerfectHash(allocator: std.mem.Allocator, keys: []const []const u8) !void {
    const e = 2;
    const m = keys.len * (1 + e);
    const r = std.math.sqrt(m);

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

    var E = try allocator.alloc(u8, buckets.len);
    @memset(E, 0);
    defer allocator.free(E);

    var T = try allocator.alloc(bool, m);
    @memset(T, false);
    defer allocator.free(T);

    var K = try allocator.alloc(u32, keys.len);
    defer allocator.free(K);

    for (0.., buckets) |i, *B| {
        defer B.deinit();
        l_loop: for (1..std.math.maxInt(u8) + 1) |l| {
            @memset(K, 0);
            var B_iter = B.iterator();
            while (B_iter.next()) |elem| {
                var D = Hash.init(0);
                D.update(elem.*);
                D.update(&[_]u8{@intCast(l)});
                const hash = D.final();

                if (T[hash % T.len]) {
                    continue :l_loop;
                }
                K[hash % K.len] = hash;
            }

            if (!std.mem.containsAtLeast(u32, K, K.len - B.count() + 1, &.{0})) {
                E[i] = @intCast(l);
                for (K) |j| {
                    T[j % T.len] = true;
                }
                break;
            }
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    try generatePerfectHash(allocator, &example_keys);
}
