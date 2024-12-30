const std = @import("std");

const g = 0;
const h = 1;

fn w(a: u8, b: u8) usize {
    return @intFromBool(a != b);
}

const Phase = enum { forward, backward };

inline fn phase_index(i: usize, A: []const u8, phase: Phase) u8 {
    return switch (phase) {
        Phase.forward => A[i],
        Phase.backward => A[A.len - i - 1],
    };
}

pub fn cost(allocator: std.mem.Allocator, A: []const u8, B: []const u8) !usize {
    const CC = try allocator.alloc(usize, B.len + 1);
    defer allocator.free(CC);

    const DD = try allocator.alloc(usize, B.len + 1);
    defer allocator.free(DD);

    return adaptive_cost(A, B, CC, DD, Phase.forward, g);
}

fn adaptive_cost(
    A: []const u8,
    B: []const u8,
    CC: []usize,
    DD: []usize,
    phase: Phase,
    ta: usize,
) usize {
    for (0..B.len) |i| CC[i] = i;
    for (0..B.len) |i| DD[i] = i;

    var t: usize = g;
    for (0..B.len) |j| {
        CC[j + 1] = t + h;
        t = t + h;
        DD[j + 1] = t + g;
    }

    var e: usize = 0;
    var c: usize = 0;
    var s: usize = 0;
    t = ta; // *
    for (0..A.len) |i| {
        s = CC[0];
        t = t + h;
        c = t;
        CC[0] = t;
        e = t + g;
        for (0..B.len) |j| {
            e = @min(e, c + g) + h;
            DD[j + 1] = @min(DD[j + 1], CC[j + 1] + g) + h;
            c = @min(DD[j + 1], e, s + w(phase_index(i, A, phase), phase_index(j, B, phase)));
            s = CC[j + 1];
            CC[j + 1] = c;
        }
    }

    return CC[B.len];
}
