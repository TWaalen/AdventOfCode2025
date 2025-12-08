const std = @import("std");

pub fn solve(part: i8, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    var findMaxJoltageInBank: *const fn ([]const u8) std.fmt.ParseIntError!u64 = undefined;
    if (part == 1) { findMaxJoltageInBank = findMaxJoltageInBank_part1; }
    else if (part == 2) { findMaxJoltageInBank = findMaxJoltageInBank_part2; }
    else { return error.NotImplemented; }

    var totalMaxJoltage: u64 = 0;
    while (true) {
        _ = reader.streamDelimiter(&writer.*.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1);

        totalMaxJoltage += try findMaxJoltageInBank(writer.*.written());

        writer.*.clearRetainingCapacity();
    }

    return totalMaxJoltage;
}

fn findMaxJoltageInBank_part1(bank: []const u8) !u64 {
    var maxLeftJoltage: u8 = '0';
    var maxRightJoltage: u8 = '0';
    for (bank, 0..) |joltage, i| {
        if (i != bank.len - 1 and joltage > maxLeftJoltage)
        {
            maxLeftJoltage = joltage;
            maxRightJoltage = '0';
        }
        else if (joltage > maxRightJoltage) { maxRightJoltage = joltage; }
    }
    return (maxLeftJoltage - 48) * 10 + maxRightJoltage - 48;
}

fn findMaxJoltageInBank_part2(bank: []const u8) !u64 {
    var maxJoltage: [12]u8 = undefined;
    @memset(&maxJoltage, '0');

    for (bank, 0..) |joltage, i| {
        for (0..12) |j| {
            if (i > bank.len - (12 - j)) { continue; }
            if (joltage > maxJoltage[j]) {
                maxJoltage[j] = joltage;
                if (j != 11) { @memset(maxJoltage[j + 1..12], '0'); }
                break;
            }
        }
    }

    return try std.fmt.parseInt(u64, &maxJoltage, 10);
}

test "max joltage in bank (part 1)" {
    const cases = [_] struct {
        input: []const u8,
        expected: u8,
    }{
        .{ .input = "987654321111111", .expected = 98 },
        .{ .input = "811111111111119", .expected = 89 },
        .{ .input = "234234234234278", .expected = 78 },
        .{ .input = "818181911112111", .expected = 92 },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {s}\n", .{case.input});
        const result = findMaxJoltageInBank_part1(case.input);
        try std.testing.expectEqual(case.expected, result);
    }
}

test "max joltage in bank (part 2)" {
    const cases = [_] struct {
        input: []const u8,
        expected: u64,
    }{
        .{ .input = "987654321111111", .expected = 987654321111 },
        .{ .input = "811111111111119", .expected = 811111111119 },
        .{ .input = "234234234234278", .expected = 434234234278 },
        .{ .input = "818181911112111", .expected = 888911112111 },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {s}\n", .{case.input});
        const result = findMaxJoltageInBank_part2(case.input);
        try std.testing.expectEqual(case.expected, result);
    }
}