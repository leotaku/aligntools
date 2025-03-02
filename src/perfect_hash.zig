const std = @import("std");
const Hash = std.hash.XxHash32;

fn bufSetGreaterThan(_: void, lhs: std.BufSet, rhs: std.BufSet) bool {
    return lhs.count() > rhs.count();
}

fn bufSetIndexGreaterThan(sets: []const std.BufSet, lhs: usize, rhs: usize) bool {
    return sets[lhs].count() > sets[rhs].count();
}

pub const PerfectHash = struct {
    E: []u8,
    m: usize,
    allocator: std.mem.Allocator,

    pub fn build(allocator: std.mem.Allocator, keys: []const []const u8) !PerfectHash {
        const e = 0;
        const m = keys.len * (1 + e);
        const r = std.math.sqrt(m);

        const buckets = try allocator.alloc(std.BufSet, r);
        defer allocator.free(buckets);
        for (buckets) |*bucket| {
            bucket.* = std.BufSet.init(allocator);
        }

        const indices = try allocator.alloc(usize, r);
        defer allocator.free(indices);
        for (keys) |key| {
            const i = Hash.hash(0, key) % r;
            try buckets[i].insert(key);
            indices[i] = i;
        }

        std.mem.sort(usize, indices, buckets, bufSetIndexGreaterThan);
        std.mem.sort(std.BufSet, buckets, {}, bufSetGreaterThan);

        var E = try allocator.alloc(u8, buckets.len);
        @memset(E, 0);

        var T = try allocator.alloc(bool, m);
        @memset(T, false);
        defer allocator.free(T);

        var K = try allocator.alloc(u32, keys.len);
        defer allocator.free(K);

        for (indices, buckets) |i, *B| {
            defer B.deinit();
            l_loop: for (1..std.math.maxInt(u8) + 1) |l| {
                @memset(K, 0);
                var B_iter = B.iterator();
                while (B_iter.next()) |elem| {
                    var D = Hash.init(0);
                    D.update(elem.*);
                    D.update(&[_]u8{@intCast(l)});
                    const final = D.final();

                    if (T[final % T.len]) {
                        continue :l_loop;
                    }
                    K[final % K.len] = final;
                }

                if (!std.mem.containsAtLeast(u32, K, K.len - B.count() + 1, &.{0})) {
                    E[i] = @intCast(l);
                    for (K) |j| {
                        if (j != 0) {
                            T[j % T.len] = true;
                        }
                    }
                    break;
                } else if (l >= std.math.maxInt(u8)) {
                    return error.PerfectHashTimeout;
                }
            }
        }

        return .{
            .allocator = allocator,
            .E = E,
            .m = m,
        };
    }

    pub fn deinit(self: *PerfectHash) void {
        self.allocator.free(self.E);
    }

    pub fn hash(self: *PerfectHash, key: []const u8) u32 {
        var D = Hash.init(0);
        D.update(key);
        D.update(&[_]u8{self.E[D.final() % self.E.len]});

        return @intCast(D.final() % self.m);
    }
};

test "no collisions" {
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

    var ph = try PerfectHash.build(std.testing.allocator, &keys);
    defer ph.deinit();

    var collisions = std.ArrayList(bool).init(std.testing.allocator);
    defer collisions.deinit();
    try collisions.appendNTimes(false, ph.m);

    for (keys) |key| {
        const hash = ph.hash(key);
        try std.testing.expect(!collisions.items[hash]);
        collisions.items[hash] = true;
    }
}
