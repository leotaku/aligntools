const std = @import("std");
const PerfectHash = @import("perfect_hash.zig").PerfectHash;
const hirschberg_gotoh = @import("hirschberg_gotoh.zig");

const Command = struct {
    const help =
        \\Usage: aligntools [OPTIONS] A B
        \\Align sections in given files.
        \\
        \\  -s, --split   Split input on the given sequence
        \\  -e, --empty   Character to serve as the empty marker
        \\  -c, --columns Line wrap at the given column
        \\  -O, --infix   Infix marker to apply to output filenames
        \\      --help    Print this message and exit
        \\
    ;

    const Error = error{
        MissingArgument,
        UnknownOption,
        IncorrectNumberOfPositionalArguments,
        ArgumentIsNotCharacter,
        ArgumentIsNotInteger,
    };

    help_shown: bool = false,
    split: []const u8 = "",
    empty: u8 = ' ',
    column: usize = 0,
    infix: []const u8 = ".aligned",
    positional: std.ArrayList([]const u8),

    fn eatOption(arg: []const u8, args: *std.process.ArgIterator, comptime short: u8, comptime long: []const u8) !?[]const u8 {
        if (std.mem.startsWith(u8, arg, "--" ++ long)) {
            if (arg.len > 2 + long.len) {
                if (arg[2 + long.len] == '=') return arg[2 + long.len + 1 ..];
                return null;
            }
            return args.next() orelse Error.MissingArgument;
        } else if (std.mem.startsWith(u8, arg, "-" ++ .{short})) {
            if (arg.len > 2) return arg[2..];
            return args.next() orelse Error.MissingArgument;
        }

        return null;
    }

    pub fn init(allocator: std.mem.Allocator) !Command {
        return .{
            .positional = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Command) void {
        self.positional.deinit();
    }

    pub fn parseFromArgs(self: *Command, args: *std.process.ArgIterator) !void {
        _ = args.next();
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--help")) {
                self.help_shown = true;
                return try std.io.getStdOut().writer().print(help, .{});
            } else if (std.mem.eql(u8, arg, "--")) {
                while (args.next()) |pos_arg| try self.positional.append(pos_arg);
            } else if (try eatOption(arg, args, 's', "split")) |it| {
                self.split = it;
            } else if (try eatOption(arg, args, 'c', "column")) |it| {
                self.column = std.fmt.parseInt(usize, it, 10) catch return Error.ArgumentIsNotInteger;
            } else if (try eatOption(arg, args, 'e', "empty")) |it| {
                self.empty = if (it.len == 1) it[0] else return Error.ArgumentIsNotCharacter;
            } else if (try eatOption(arg, args, 'O', "infix")) |it| {
                self.infix = it;
            } else if (std.mem.startsWith(u8, arg, "-")) {
                return Error.UnknownOption;
            } else {
                try self.positional.append(arg);
            }
        }

        if (self.positional.items.len != 2) {
            return Error.IncorrectNumberOfPositionalArguments;
        }
    }

    pub fn handleError(err: anyerror) !u8 {
        const message = switch (err) {
            Error.MissingArgument => "missing option argument",
            Error.UnknownOption => "unknown option",
            Error.IncorrectNumberOfPositionalArguments => "incorrect number of positional arguments",
            Error.ArgumentIsNotCharacter => "argument is not a character",
            Error.ArgumentIsNotInteger => "argument is not an integer",
            else => return err,
        };

        const stderr = std.io.getStdErr().writer();
        try stderr.print(help, .{});
        try stderr.print("\nerror: {s}\n", .{message});
        return 1;
    }
};

fn readFile(allocator: std.mem.Allocator, sub_path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(sub_path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

fn createWithInfix(allocator: std.mem.Allocator, sub_path: []const u8, infix: []const u8) !std.fs.File {
    const name_with_infix = try nameWithInfix(allocator, sub_path, infix);
    defer allocator.free(name_with_infix);
    return std.fs.cwd().createFile(name_with_infix, .{});
}

fn nameWithInfix(allocator: std.mem.Allocator, sub_path: []const u8, infix: []const u8) ![]u8 {
    const index = std.mem.lastIndexOfScalar(u8, sub_path, '.') orelse sub_path.len;
    return std.mem.concat(allocator, u8, &[_][]const u8{ sub_path[0..index], infix, sub_path[index..] });
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var command = try Command.init(allocator);
    defer command.deinit();
    command.parseFromArgs(&args) catch |err| return Command.handleError(err);
    if (command.help_shown) return 0;

    if (command.split.len != 0) return error.Unimplemented;
    if (command.column != 0) return error.Unimplemented;

    const A = try readFile(allocator, command.positional.items[0]);
    defer allocator.free(A);
    const B = try readFile(allocator, command.positional.items[1]);
    defer allocator.free(B);

    var edits = try hirschberg_gotoh.transform(allocator, A, B);
    defer edits.deinit();

    const A_aligned = try createWithInfix(allocator, command.positional.items[0], command.infix);
    defer A_aligned.close();
    const B_aligned = try createWithInfix(allocator, command.positional.items[1], command.infix);
    defer B_aligned.close();

    var A_i: usize = 0;
    var B_i: usize = 0;
    for (edits.items) |edit| {
        switch (edit) {
            .delete => |data| {
                _ = try A_aligned.write(A[A_i .. A_i + data.len]);
                _ = try B_aligned.writer().writeByteNTimes(command.empty, data.len);
                A_i += data.len;
            },
            .insert => |data| {
                _ = try A_aligned.writer().writeByteNTimes(command.empty, data.len);
                _ = try B_aligned.write(B[B_i .. B_i + data.len]);
                B_i += data.len;
            },
            .replace => |data| {
                _ = try A_aligned.write(A[A_i .. A_i + data.len]);
                _ = try B_aligned.write(B[B_i .. B_i + data.len]);
                A_i += data.len;
                B_i += data.len;
            },
        }
    }

    return 0;
}

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
    try hirschberg_gotoh.write_edits(std.io.getStdOut().writer(), edits.items);
}
