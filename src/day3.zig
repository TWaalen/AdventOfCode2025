const std = @import("std");

pub fn solve(part: i8, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    if (part != 1) { return error.NotImplemented; }

    var totalMaxJoltage: u64 = 0;
    while (true) {
        _ = reader.streamDelimiter(&writer.*.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1);

        totalMaxJoltage += findMaxJoltageInBank(writer.*.written());

        writer.*.clearRetainingCapacity();
    }

    return totalMaxJoltage;
}

fn findMaxJoltageInBank(bank: []const u8) u8 {
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

test "max joltage in bank" {
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
        const result = findMaxJoltageInBank(case.input);
        try std.testing.expectEqual(case.expected, result);
    }
}