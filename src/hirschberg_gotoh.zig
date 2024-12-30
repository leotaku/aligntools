const std = @import("std");

const g = 0;
const h = 1;

fn w(a: u8, b: u8) usize {
    return @intFromBool(a != b);
}

pub fn cost(allocator: std.mem.Allocator, A: []const u8, B: []const u8) !usize {
    var CC = try allocator.alloc(usize, B.len + 1);
    for (0.., CC) |i, *cc| cc.* = i;
    defer allocator.free(CC);

    var DD = try allocator.alloc(usize, B.len + 1);
    for (0.., DD) |i, *dd| dd.* = i;
    defer allocator.free(DD);

    var t: usize = g;
    for (1..B.len + 1) |j| {
        CC[j] = t + h;
        t = t + h;
        DD[j] = t + g;
    }

    var e: usize = 0;
    var c: usize = 0;
    var s: usize = 0;
    t = g;
    for (1..A.len + 1) |i| {
        s = CC[0];
        t = t + h;
        c = t;
        CC[0] = t;
        e = t + g;
        for (1..B.len + 1) |j| {
            e = @min(e, c + g) + h;
            DD[j] = @min(DD[j], CC[j] + g) + h;
            c = @min(DD[j], e, s + w(A[i - 1], B[j - 1]));
            s = CC[j];
            CC[j] = c;
        }
    }

    return CC[B.len];
}
