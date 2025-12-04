const std = @import("std");

/// The result of a dial turn
pub const DialTurnResult = struct {
    /// The dial index after turning the dial
    dialIndex: i16,
    /// The (accumulated) password after turning the dial
    password: i16,
};

pub fn parseDialTurn(input: []const u8) !i16 {
    const direction = input[0];
    const steps = try std.fmt.parseInt(i16, input[1..], 10);

    if (direction == 'R') {
        return steps;
    }

    return -steps;
}

pub fn executeDialTurn_part1(dialIndex: i16, password: i16, delta: i16) !DialTurnResult {
    const newDialIndex = @mod(dialIndex + delta, 100);
    var newPassword = password;
    if (dialIndex == 0) newPassword += 1;

    return .{
        .dialIndex = newDialIndex,
        .password = if (newDialIndex == 0) password + 1 else password,
    };
}

pub fn executeDialTurn_part2(dialIndex: i16, password: i16, delta: i16) !DialTurnResult {
    var newDialIndex = dialIndex + delta;
    const absNewDialIndex = @abs(newDialIndex);

    var zeroTicks: i16 = 0;
    if (absNewDialIndex >= 100) {
        zeroTicks = @intCast(@divTrunc(absNewDialIndex, 100));
        if (dialIndex != 0 and delta < 0) {
            zeroTicks += 1;
        }
    } else if (delta < 0 and newDialIndex <= 0 and dialIndex > 0) {
        zeroTicks = 1;
    } else if (delta == 0) {
        return error.NotImplemented;
    }

    newDialIndex = @mod(newDialIndex, 100);

    return .{
        .dialIndex = newDialIndex,
        .password = password + zeroTicks,
    };
}

test "parsing" {
    const cases = [_]struct {
        input: []const u8,
        expected: i16,
    }{
        .{ .input = "R18", .expected =    18 },
        .{ .input = "L96", .expected =  - 96 },
        .{ .input = "R998", .expected =  998 },
        .{ .input = "L998", .expected = -998 },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {any}\n", .{case.input});
        const result = try parseDialTurn(case.input);
        try std.testing.expectEqual(case.expected, result);
    }
}

test "turning (part 1)" {
    const cases = [_] struct {
        input: struct {
            dialIndex: i16,
            steps: i16,
        },
        expected: DialTurnResult
    }{
        .{
            .input = .{ .dialIndex = 4, .steps = 40},
            .expected = .{ .dialIndex = 44, .password = 0},
        }, .{
            .input = .{ .dialIndex = 20, .steps = -16 },
            .expected = .{ .dialIndex = 4, .password = 0 },
        }, .{
            .input = .{ .dialIndex = 30, .steps = 80 },
            .expected = .{ .dialIndex = 10, .password = 0 },
        }, .{
            .input = .{ .dialIndex = 30, .steps = -40 },
            .expected = .{ .dialIndex = 90, .password = 0 },
        }, .{
            .input = .{ .dialIndex = 99, .steps = 998 },
            .expected = .{ .dialIndex = 97, .password = 0 },
        }, .{
            .input = .{ .dialIndex = 0, .steps = -998 },
            .expected = .{ .dialIndex = 2, .password = 0 },
        }, .{
            .input = .{ .dialIndex = 2, .steps = 98 },
            .expected = .{ .dialIndex = 0, .password = 1 },
        }, .{
            .input = .{ .dialIndex = 89, .steps = -89 },
            .expected = .{ .dialIndex = 0, .password = 1 },
        }, .{
            .input = .{ .dialIndex = 12, .steps = 288 },
            .expected = .{ .dialIndex = 0, .password = 1 },
        }, .{
            .input = .{ .dialIndex = 22, .steps = -322 },
            .expected = .{ .dialIndex = 0, .password = 1 },
        },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {any}\n", .{case.input});
        const result = executeDialTurn_part1(case.input.dialIndex, 0,
            case.input.steps);
        try std.testing.expectEqualDeep(case.expected, result);
    }
}

test "turning (part 2)" {
    const cases = [_] struct {
        input: struct {
            dialIndex: i16,
            steps: i16,
        },
        expected: DialTurnResult
    }{
        .{
            .input = .{ .dialIndex = 4, .steps = 40},
            .expected = .{ .dialIndex = 44, .password = 0},
        }, .{
            .input = .{ .dialIndex = 20, .steps = -16 },
            .expected = .{ .dialIndex = 4, .password = 0 },
        }, .{
            .input = .{ .dialIndex = 30, .steps = 80 },
            .expected = .{ .dialIndex = 10, .password = 1 },
        }, .{
            .input = .{ .dialIndex = 30, .steps = -40 },
            .expected = .{ .dialIndex = 90, .password = 1 },
        }, .{
            .input = .{ .dialIndex = 99, .steps = 998 },
            .expected = .{ .dialIndex = 97, .password = 10 },
        }, .{
            .input = .{ .dialIndex = 0, .steps = -998 },
            .expected = .{ .dialIndex = 2, .password = 9 },
        }, .{
            .input = .{ .dialIndex = 2, .steps = 98 },
            .expected = .{ .dialIndex = 0, .password = 1 },
        }, .{
            .input = .{ .dialIndex = 89, .steps = -89 },
            .expected = .{ .dialIndex = 0, .password = 1 },
        }, .{
            .input = .{ .dialIndex = 12, .steps = 288 },
            .expected = .{ .dialIndex = 0, .password = 3 },
        }, .{
            .input = .{ .dialIndex = 22, .steps = -322 },
            .expected = .{ .dialIndex = 0, .password = 4 },
        },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {any}\n", .{case.input});
        const result = executeDialTurn_part2(case.input.dialIndex, 0,
            case.input.steps);
        try std.testing.expectEqualDeep(case.expected, result);
    }
}

test "integration test (part 1)" {
    const input = [_][]const u8 {
        "L68",
        "L30",
        "R48",
        "L5",
        "R60",
        "L55",
        "L1",
        "L99",
        "R14",
        "L82",
    };

    var dialIndex: i16 = 50;
    var password: i16 = 0;
    for (input) |dialTurn| {
        const steps = try parseDialTurn(dialTurn);
        const result = try executeDialTurn_part1(dialIndex, password, steps);
        dialIndex = result.dialIndex;
        password = result.password;
    }

    try std.testing.expectEqual(32, dialIndex);
    try std.testing.expectEqual(3, password);
}

test "integration test (part 2)" {
    const input = [_][] const u8 {
        "L68",
        "L30",
        "R48",
        "L5",
        "R60",
        "L55",
        "L1",
        "L99",
        "R14",
        "L82",
    };

    var dialIndex: i16 = 50;
    var password: i16 = 0;
    for (input) |dialTurn| {
        const steps = try parseDialTurn(dialTurn);
        const result = try executeDialTurn_part2(dialIndex, password, steps);
        dialIndex = result.dialIndex;
        password = result.password;
    }

    try std.testing.expectEqual(32, dialIndex);
    try std.testing.expectEqual(6, password);
}
