const std = @import("std");

pub fn solve(part: i8, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    var isInvalidId: *const fn (u64) bool = undefined;
    if (part == 1) { isInvalidId = isInvalidId_part1; }
    else if (part == 2) { isInvalidId = isInvalidId_part2; }
    else { return error.NotImplemented; }

    var reachedEndOfStream = false;
    var invalidIdSum: u64 = 0;
    while(!reachedEndOfStream) {
        _ = reader.streamDelimiter(&writer.*.writer, ',') catch |err| {
            if (err == error.EndOfStream) reachedEndOfStream = true else return err;
        };

        if (!reachedEndOfStream) {
            _ = reader.toss(1);
        }

        const minId, const maxId = try parseIdRange(writer.*.written());
        invalidIdSum += sumInvalidIdsInRange(minId, maxId, isInvalidId);

        writer.*.clearRetainingCapacity();
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
    for (@intCast(minId)..@intCast(maxId + 1)) |id| {
        if (isInvalidId(id)) {
            invalidIdSum += id;
        }
    }

    return invalidIdSum;
}

fn isInvalidId_part1(id: u64) bool {
    const digits = std.math.log10_int(id) + 1;
    if (@rem(digits, 2) != 0) { return false; }

    var divisor: usize = 10;
    for (1..digits / 2) |_| {
        divisor *= 10;
    }

    return @divTrunc(id, divisor) == @rem(id, divisor);
}

fn isInvalidId_part2(id: u64) bool {
    const digits = std.math.log10_int(id) + 1;

    var length = digits / 2;
    while (length > 0) {
        if (@rem(digits, length) != 0) {
            length -= 1;
            continue;
        }

        if (hasSequenceOfLength(id, digits, length)) {
            return true;
        }
        length -= 1;
    }

    return false;
}

fn hasSequenceOfLength(id: u64, digits: u64, length: u64) bool {
    var divisor: u64 = 10;
    for (1..length) |_| {
        divisor *= 10;
    }

    const sequenceCandidate = @rem(id, divisor);
    var checkId = @divTrunc(id, divisor);
    for (1..digits / length) |_| {
        if (@rem(checkId, divisor) != sequenceCandidate) { return false; }
        checkId = @divTrunc(checkId, divisor);
    }

    return true;
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

test "sum invalid (part 2)" {
    const cases = [_] struct {
        input: struct { i64, i64 },
        expected: usize,
    }{
        .{ .input = .{ 292, 399 }, .expected = 333 },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {any}\n", .{case.input});
        const result = sumInvalidIdsInRange(case.input[0], case.input[1], isInvalidId_part2);
        try std.testing.expectEqual(case.expected, result);
    }
}

test "is invalid (part 2)" {
    const cases = [_] struct {
        input: u64,
        expected: bool,
    }{
        .{ .input = 11111, .expected = true },
        .{ .input = 1212121212, .expected = true },
        .{ .input = 123123, .expected = true },
        .{ .input = 123123123, .expected = true },
        .{ .input = 333, .expected = true },
        .{ .input = 124123, .expected = false },
        .{ .input = 1000, .expected = false },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {d}\n", .{case.input});
        const result = isInvalidId_part2(case.input);
        try std.testing.expectEqual(case.expected, result);
    }
}

test "integration test" {
    const input = [_][]const u8 {
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

    const cases = [_] struct {
        isInvalidId: *const fn(u64) bool,
        expected: u64,
    }{
        .{ .isInvalidId = isInvalidId_part1, .expected = 1227775554 },
        .{ .isInvalidId = isInvalidId_part2, .expected = 4174379265 },
    };

    for (cases) |case| {
        var invalidIdSum: usize = 0;
        for (input) |range| {
            const minId, const maxId = try parseIdRange(range);
            invalidIdSum += sumInvalidIdsInRange(minId, maxId, case.isInvalidId);
        }

        try std.testing.expectEqual(case.expected, invalidIdSum);
    }
}

test "find sequence" {
    const cases = [_] struct {
        input: struct {
            id: u64,
            digits: u64,
            length: u8,
        },
        expected: bool,
    }{
        .{
            .input = .{
                .id = 11111,
                .digits = 5,
                .length = 1
            },
            .expected = true,
        },
        .{
            .input = .{
                .id = 12341234,
                .digits = 8,
                .length = 4,
            },
            .expected = true,
        },
        .{
            .input = .{
                .id = 123124,
                .digits = 6,
                .length = 3,
            },
            .expected = false,
        },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {any}\n", .{case.input});
        const result = hasSequenceOfLength(case.input.id, case.input.digits, case.input.length);
        try std.testing.expectEqual(case.expected, result);
    }
}
