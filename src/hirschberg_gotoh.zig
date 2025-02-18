const std = @import("std");

const g = 0;
const h = 1;

inline fn w(a: u8, b: u8) usize {
    return @intFromBool(a != b);
}

const Phase = enum { forward, backward };

inline fn phaseIndex(i: usize, A: []const u8, phase: Phase) u8 {
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

    return adaptiveCost(A, B, CC, DD, Phase.forward, g);
}

fn adaptiveCost(
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
            c = @min(DD[j + 1], e, s + w(phaseIndex(i, A, phase), phaseIndex(j, B, phase)));
            s = CC[j + 1];
            CC[j + 1] = c;
        }
    }

    return CC[B.len];
}

pub const Edit = union(enum) {
    insert: []const u8,
    delete: []const u8,
    replace: []const u8,
};

fn coalescingAppend(list: *std.ArrayList(Edit), edit: Edit) !void {
    if (list.items.len == 0) return try list.append(edit);
    const last: *Edit = &list.items[list.items.len - 1];

    if (std.meta.activeTag(last.*) != std.meta.activeTag(edit)) {
        return try list.append(edit);
    }

    switch (edit) {
        .delete => last.*.delete.len += edit.delete.len,
        .insert => last.*.insert.len += edit.insert.len,
        .replace => last.*.replace.len += edit.replace.len,
    }
}

pub fn transform(allocator: std.mem.Allocator, A: []const u8, B: []const u8) !std.ArrayList(Edit) {
    const CC = try allocator.alloc(usize, B.len + 1);
    defer allocator.free(CC);

    const DD = try allocator.alloc(usize, B.len + 1);
    defer allocator.free(DD);

    const RR = try allocator.alloc(usize, B.len + 1);
    defer allocator.free(RR);

    const SS = try allocator.alloc(usize, B.len + 1);
    defer allocator.free(SS);

    var edits = std.ArrayList(Edit).init(allocator);
    errdefer edits.deinit();
    try adaptiveTransform(A, B, CC, DD, RR, SS, g, g, &edits);
    return edits;
}

fn adaptiveTransform(
    A: []const u8,
    B: []const u8,
    CC: []usize,
    DD: []usize,
    RR: []usize,
    SS: []usize,
    tb: usize,
    te: usize,
    edits: *std.ArrayList(Edit),
) !void {
    if (B.len == 0) {
        if (A.len > 0) try coalescingAppend(edits, Edit{ .delete = A[0..] });
    } else switch (A.len) {
        0 => try coalescingAppend(edits, Edit{ .insert = B[0..] }),
        1 => {
            const default_cost = @min(tb, te) + h + (B.len * h + g);
            var @"j*": usize = undefined;
            var min_replace_cost: usize = std.math.maxInt(usize);
            for (0..B.len) |j| {
                const replace_cost = j * h + g + w(A[0], B[j]) + (B.len - j - 1) * h + g;
                if (replace_cost < min_replace_cost) {
                    min_replace_cost = replace_cost;
                    @"j*" = j;
                }
            }

            if (min_replace_cost < default_cost) {
                if (@"j*" >= 1) try coalescingAppend(edits, Edit{ .insert = B[0..@"j*"] });
                try coalescingAppend(edits, Edit{ .replace = B[@"j*" .. @"j*" + 1] });
                if (B.len - @"j*" > 1) try coalescingAppend(edits, Edit{ .insert = B[@"j*" + 1 ..] });
            } else {
                try coalescingAppend(edits, Edit{ .insert = B[0..] });
            }
        },
        else => {
            const @"i*" = A.len / 2;
            _ = adaptiveCost(A[0..@"i*"], B, CC, DD, Phase.forward, tb);
            _ = adaptiveCost(A[@"i*"..], B, RR, SS, Phase.backward, te);
            var @"j*": usize = undefined;
            var is_type1: bool = undefined;
            var min_cost: usize = std.math.maxInt(usize);
            for (0..B.len + 1) |j| {
                const type1_cost = CC[j] + RR[B.len - j];
                const type2_cost = DD[j] + SS[B.len - j] - g;
                if (@min(type1_cost, type2_cost) < min_cost) {
                    min_cost = @min(type1_cost, type2_cost);
                    @"j*" = j;
                    is_type1 = type1_cost <= type2_cost;
                }
            }

            if (is_type1) {
                try adaptiveTransform(A[0..@"i*"], B[0..@"j*"], CC, DD, RR, SS, tb, g, edits);
                try adaptiveTransform(A[@"i*"..], B[@"j*"..], CC, DD, RR, SS, g, te, edits);
            } else {
                try adaptiveTransform(A[0 .. @"i*" - 1], B[0..@"j*"], CC, DD, RR, SS, tb, 0, edits);
                try coalescingAppend(edits, Edit{ .delete = A[@"i*" .. @"i*" + 2] });
                try adaptiveTransform(A[@"i*" + 1 ..], B[@"j*"..], CC, DD, RR, SS, 0, te, edits);
            }
        },
    }
}

pub fn writeEdits(writer: anytype, edits: []const Edit) !void {
    for (edits) |edit| switch (edit) {
        .delete => |e| for (0..e.len) |_| try writer.writeByte('-'),
        .insert => |e| _ = try writer.write(e),
        .replace => |e| for (0..e.len) |_| try writer.writeByte('?'),
    };
    try writer.writeByte('\n');
    for (edits) |edit| switch (edit) {
        .delete => |e| try writer.writeByteNTimes('d', e.len),
        .insert => |e| try writer.writeByteNTimes('i', e.len),
        .replace => |e| try writer.writeByteNTimes('r', e.len),
    };
    try writer.writeByte('\n');
    for (edits) |edit| switch (edit) {
        .delete => |e| _ = try writer.write(e),
        .insert => |e| for (0..e.len) |_| try writer.writeByte('-'),
        .replace => |e| _ = try writer.write(e),
    };
    try writer.writeByte('\n');
}
