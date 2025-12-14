const std = @import("std");

pub fn solve(reader: *std.Io.Reader) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ranges = std.ArrayList(struct { u64, u64 }).empty;
    defer ranges.deinit(allocator);

    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    while (true) {
        const bytesRead = reader.streamDelimiter(&writer.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        reader.toss(1);

        if (bytesRead == 0) { break; }

        try ranges.append(allocator, try parseIdRange(writer.written()));
        writer.clearRetainingCapacity();
    }

    var freshIngredientCount: u64 = 0;
    while (true) {
        _ = reader.streamDelimiter(&writer.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        reader.toss(1);

        const id = try std.fmt.parseInt(u64, writer.written(), 10);
        for (ranges.items) |range| {
            if (isIdInRange(id, range)) {
                freshIngredientCount += 1;
                break;
            }
        }

        writer.clearRetainingCapacity();
    }

    return freshIngredientCount;
}

fn parseIdRange(input: []const u8) !struct { u64, u64 } {
    var splitIterator = std.mem.splitScalar(u8, input, '-');
    const minId = try std.fmt.parseInt(u64, splitIterator.next().?, 10);
    const maxId =  try std.fmt.parseInt(u64, splitIterator.next().?, 10);

    return .{ minId, maxId };
}

inline fn isIdInRange(id: u64, range: struct { u64, u64 }) bool {
    return id >= range[0] and id <= range[1];
}

test parseIdRange {
    const cases = [_] struct {
        input: []const u8,
        expected: struct { u64, u64 },
    }{
        .{ .input = "11-22", .expected = .{ 11, 22 } },
        .{ .input = "2121212118-2121212124", .expected = .{ 2121212118, 2121212124 } },
        .{ .input = "8989806846-8989985017", .expected = .{ 8989806846, 8989985017 } },
        .{ .input = "35-54", .expected = .{ 35, 54 } },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {s}\n", .{case.input});
        try std.testing.expectEqualDeep(case.expected, parseIdRange(case.input));
    }
}

test isIdInRange {
    const cases = [_] struct {
        input: struct {
            id: u64,
            range: struct { u64, u64 },
        },
        expected: bool,
    }{
        .{
            .input = .{ .id = 22, .range = .{ 11, 22 } },
            .expected = true,
        }, .{
            .input = .{ .id = 2121212120, .range = .{ 2121212118, 2121212124 } },
            .expected = true,
        }, .{
           .input = .{ .id = 2334345, .range = .{ 8989806846, 8989985017 } },
            .expected = false
        }
    };

    for (cases) |case| {
        errdefer std.debug.print("input: (id: {d}, range: [{d}-{d}])\n", .{case.input.id, case.input.range[0], case.input.range[1]});
        try std.testing.expectEqual(case.expected, isIdInRange(case.input.id, case.input.range));
    }
}

test "passes example input" {
    const input: []const u8 =
        \\3-5
        \\10-14
        \\16-20
        \\12-18
        \\
        \\1
        \\5
        \\8
        \\11
        \\17
        \\32
    ;

    var reader = std.Io.Reader.fixed(input);
    try std.testing.expectEqual(3, solve(&reader));
}

