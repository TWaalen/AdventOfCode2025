const std = @import("std");

pub fn solve(part: i8, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    if (part == 2) { return 0; }
    var invalidIdSum: u64 = 0;
    while(true) {
        _ = reader.streamDelimiter(&writer.*.writer, ',') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1);

        const minId, const maxId = try parseIdRange(writer.*.written());
        invalidIdSum += sumInvalidIdsInRange(minId, maxId, isInvalidId_part1);

        writer.*.clearRetainingCapacity();
    }

    if (writer.*.written().len > 0) {
        const minId, const maxId = try parseIdRange(writer.*.written());
        invalidIdSum += sumInvalidIdsInRange(minId, maxId, isInvalidId_part1);
    }

    return invalidIdSum;
}

fn parseIdRange(input: []const u8) !struct { i64, i64 } {
    var splitIterator = std.mem.splitAny(u8, input, "-,\n");
    const minId = try std.fmt.parseInt(i64, splitIterator.next().?, 10);
    const maxId =  try std.fmt.parseInt(i64, splitIterator.next().?, 10);

    return .{ minId, maxId };
}

fn sumInvalidIdsInRange(minId: i64, maxId: i64, isInvalidId: *const fn (u64) bool) u64 {
    var invalidIdSum: usize = 0;
    if (minId >= 100 and maxId <= 1000) { return invalidIdSum; }
    for (@intCast(minId)..@intCast(maxId + 1)) |id| {
        if (isInvalidId(id)) {
            invalidIdSum += id;
        }
    }

    return invalidIdSum;
}

fn isInvalidId_part1(id: u64) bool {
    const digits = std.math.log10_int(id) + 1;
    if (digits % 2 != 0) { return false; }

    var divisor: usize = 10;
    for (1..digits / 2) |_| {
        divisor *= 10;
    }

    return @divFloor(id, divisor) == @rem(id, divisor);
}

test "parsing" {
    const cases = [_]struct {
        input: []const u8,
        expected: struct { i64, i64 },
    }{
        .{ .input = "11-22", .expected = .{ 11, 22 } },
        .{ .input = "2121212118-2121212124", .expected = .{ 2121212118, 2121212124 } },
        .{ .input = "8989806846-8989985017", .expected = .{ 8989806846, 8989985017 } },
        .{ .input = "35-54\n", .expected = .{ 35, 54 } },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {s}\n", .{case.input});
        const result = try parseIdRange(case.input);
        try std.testing.expectEqualDeep(case.expected, result);
    }
}

test "sum invalid (part 1)" {
    const cases = [_] struct {
        input: struct { i64, i64 },
        expected: usize,
    }{
        .{ .input = .{ 234, 894 }, .expected = 0 },
        .{ .input = .{ 11, 22 }, .expected = 33 },
        .{ .input = .{ 222220, 222224 }, .expected = 222222 },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {any}\n", .{case.input} );
        const result = sumInvalidIdsInRange(case.input[0], case.input[1], isInvalidId_part1);
        try std.testing.expectEqual(case.expected, result);
    }
}

test "integration test (part 1)" {
    const input = [_][] const u8 {
        "11-22",
        "95-115",
        "998-1012",
        "1188511880-1188511890",
        "222220-222224",
        "1698522-1698528",
        "446443-446449",
        "38593856-38593862",
        "565653-565659",
        "824824821-824824827",
        "2121212118-2121212124",
    };

    var invalidIdSum: usize = 0;
    for (input) |range| {
        const minId, const maxId = try parseIdRange(range);
        invalidIdSum += sumInvalidIdsInRange(minId, maxId, isInvalidId_part1);
    }

    try std.testing.expectEqual(1227775554, invalidIdSum);
}