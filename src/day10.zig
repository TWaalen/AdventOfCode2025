const std = @import("std");

const Machine = struct {
    desiredIndicatorState: u16,
    buttons: []const u16,

    fn findMinimumInitializationPresses(self: *const Machine, allocator: std.mem.Allocator) !u64 {
        var currentLevel = std.ArrayListUnmanaged(u16).empty;
        defer currentLevel.deinit(allocator);
        try currentLevel.append(allocator, 0);
        var nextLevel = std.ArrayListUnmanaged(u16).empty;
        defer nextLevel.deinit(allocator);
        var visited = std.AutoHashMapUnmanaged(u16, void).empty;
        defer visited.deinit(allocator);
        try visited.put(allocator, 0, {});

        var presses: u64 = 0;
        while (currentLevel.items.len != 0) : ({
            const tmp = currentLevel;
            currentLevel = nextLevel;
            nextLevel = tmp;
            nextLevel.clearRetainingCapacity();
            presses += 1;
        }) {
            for (currentLevel.items) |state| {
                for (self.buttons) |buttonMask| {
                    const nextState = state ^ buttonMask;
                    if (nextState == self.desiredIndicatorState) { return presses + 1; }

                    if (!visited.contains(nextState)) {
                        try visited.put(allocator, nextState, {});
                        try nextLevel.append(allocator, nextState);
                    }
                }
            }
        }

        return error.UnableToReachDesiredState;
    }

    fn deinit(self: *Machine, allocator: std.mem.Allocator) void {
        allocator.free(self.*.buttons);
    }

    fn parse(allocator: std.mem.Allocator, input: []const u8) !Machine {
        var parsedIndicatorState: u16 = 0;
        var parsedButtons = std.ArrayListUnmanaged(u16).empty;
        defer parsedButtons.deinit(allocator);

        var i: usize = 0;
        while (i < input.len) : (i += 1) {
            switch (input[i]) {
                '[' => {
                    var bitIndex: u4 = 0;
                    i += 1;
                    while (input[i] != ']' and i < input.len) : ({
                        i += 1;
                        bitIndex += 1;
                    }) {
                        try switch (input[i]) {
                            '.' => {},
                            '#' => parsedIndicatorState |= @as(u16, 1) << bitIndex,
                            else => error.UnknownIndicatorState,
                        };
                    }
                },
                '(' => {
                    i += 1;

                    var button: u16 = 0;
                    var currentBitIndex: u8 = 0;
                    while (input[i] != ')' and i < input.len) : (i += 1) {
                        const character = input[i];
                        if (character >= '0' and character <= '9') {
                            currentBitIndex = currentBitIndex * 10 + (character - '0');
                        } else if (character == ',') {
                            button |= @as(u16, 1) << @as(u4, @intCast(currentBitIndex));
                            currentBitIndex = 0;
                        } else {
                            return error.UnknownButtonCharacter;
                        }
                    }

                    button ^= @as(u16, 1) << @as(u4, @intCast(currentBitIndex));

                    try parsedButtons.append(allocator, button);
                },
                else => {}
            }
        }

        return Machine {
            .desiredIndicatorState = parsedIndicatorState,
            .buttons = try parsedButtons.toOwnedSlice(allocator),
        };
    }
};

pub fn solve(allocator: std.mem.Allocator, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    var summedMinimemPresses: u64 = 0;
    while (reader.streamDelimiter(&writer.*.writer, '\n')) |_| : ({
        _ = reader.toss(1);
        writer.*.clearRetainingCapacity();
    }) {
        var machine = try Machine.parse(allocator, writer.*.written());
        defer machine.deinit(allocator);
        summedMinimemPresses += try machine.findMinimumInitializationPresses(allocator);
    } else |err| if (err != error.EndOfStream) return err;

    return summedMinimemPresses;
}

test "can parse example machines" {
    const cases = [_]struct {
        input: []const u8,
        expected: Machine,
    }{
        .{
            .input = "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}",
            .expected = Machine{
                .desiredIndicatorState = 0b0110,
                .buttons = &[_]u16{
                    0b1000,
                    0b1010,
                    0b0100,
                    0b1100,
                    0b0101,
                    0b0011,
                },
            },
        }, .{
            .input = "[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}",
            .expected = Machine{
                .desiredIndicatorState = 0b01000,
                .buttons = &[_]u16{
                    0b11101,
                    0b01100,
                    0b10001,
                    0b00111,
                    0b11110,
                },
            },
        }, .{
            .input = "[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}",
            .expected = Machine{
                .desiredIndicatorState = 0b101110,
                .buttons = &[_]u16{
                    0b011111,
                    0b011001,
                    0b110111,
                    0b000110,
                },
            },
        },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {s}\n", .{case.input});
        var result = try Machine.parse(std.testing.allocator, case.input);
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqualDeep(case.expected, result);
    }
}

test "can find minimum initialization presses" {
    const cases = [_]struct {
        input: Machine,
        expected: u64,
    }{
        .{
            .input = Machine{
                .desiredIndicatorState = 0b0110,
                .buttons = &[_]u16{
                    0b1000,
                    0b1010,
                    0b0100,
                    0b1100,
                    0b0101,
                    0b0011,
                },
            },
            .expected = 2,
        }, .{
            .input = Machine{
                .desiredIndicatorState = 0b01000,
                .buttons = &[_]u16{
                    0b11101,
                    0b01100,
                    0b10001,
                    0b00111,
                    0b11110,
                },
            },
            .expected = 3,
        }, .{
            .input = Machine{
                .desiredIndicatorState = 0b101110,
                .buttons = &[_]u16{
                    0b011111,
                    0b011001,
                    0b110111,
                    0b000110,
                },
            },
            .expected = 2,
        },
    };

    for (cases, 1..) |case, i| {
        errdefer std.debug.print("input: Machine {d}\n", .{i});
        const result = try case.input.findMinimumInitializationPresses(std.testing.allocator);
        try std.testing.expectEqual(case.expected, result);
    }
}

test "passes example input" {
    const input: []const u8 =
        \\[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
        \\[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
        \\[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}
        \\
    ;

    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();
    try std.testing.expectEqual(7, try solve(std.testing.allocator, &reader, &writer));
}