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
    for (0..B.len) |j| {
        CC[j + 1] = t + h;
        t = t + h;
        DD[j + 1] = t + g;
    }

    var e: usize = 0;
    var c: usize = 0;
    var s: usize = 0;
    t = g;
    for (0..A.len) |i| {
        s = CC[0];
        t = t + h;
        c = t;
        CC[0] = t;
        e = t + g;
        for (0..B.len) |j| {
            e = @min(e, c + g) + h;
            DD[j + 1] = @min(DD[j + 1], CC[j + 1] + g) + h;
            c = @min(DD[j + 1], e, s + w(A[i], B[j]));
            s = CC[j + 1];
            CC[j + 1] = c;
        }
    }

    return CC[B.len];
}
