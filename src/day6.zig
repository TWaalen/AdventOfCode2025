const std = @import("std");
const SeekableReader = @import("utils/SeekableReader.zig");

pub fn solve_part1(reader: *SeekableReader) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    const operations, const numberLines = try findOperations(reader.interface(), &writer);
    defer allocator.free(operations);
    var operationIterator = std.mem.tokenizeScalar(u8, operations, ' ');

    var results = std.ArrayList(u64).empty;
    defer results.deinit(allocator);

    try reader.seekTo(0);

    var lineIndex: u8 = 0;
    while (reader.interface().streamDelimiter(&writer.writer, '\n')) |_| {
        if (lineIndex >= numberLines) { break; }
        _ = reader.interface().toss(1);

        if (results.items.len == 0) {
            var numberIterator = std.mem.tokenizeScalar(u8, writer.written(), ' ');
            while (numberIterator.next()) |numberSlice| {
                try results.append(allocator, try std.fmt.parseInt(u64, numberSlice, 10));
            }

            writer.clearRetainingCapacity();
            lineIndex += 1;
            continue;
        }

        var numberIterator = std.mem.tokenizeScalar(u8, writer.written(), ' ');

        var i: usize = 0;
        while (numberIterator.next()) |numberSlice| {
            if (i >= results.items.len) { return error.NumberMismatch; }
            const operationSlice = operationIterator.next() orelse return error.MissingOperation;
            const number = try std.fmt.parseInt(u64, numberSlice, 10);

            results.items[i] = try doOperation(operationSlice[0], results.items[i], number);
            i += 1;
        }
        operationIterator.reset();

        writer.clearRetainingCapacity();
        lineIndex += 1;
    } else |err| if (err != error.EndOfStream) return err;

    var summedResults: u64 = 0;
    for (results.items) |result| {
        summedResults += result;
    }

    return summedResults;
}

pub fn solve_part2(reader: *SeekableReader) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    const operations, const numberLines = try findOperations(reader.interface(), &writer);
    defer allocator.free(operations);
    var operationIterator = std.mem.tokenizeScalar(u8, operations, ' ');

    var results = std.ArrayList(std.ArrayList(u64)).empty;
    try results.append(allocator, std.ArrayList(u64).empty);
    defer {
        for (results.items) |*result| {
            result.deinit(allocator);
        }
        results.deinit(allocator);
    }

    try reader.seekTo(0);

    var lineIndex: u8 = 0;
    while (reader.interface().streamDelimiter(&writer.writer, '\n')) |_| {
        if (lineIndex >= numberLines) { break; }
        _ = reader.interface().toss(1);

        var calculationIndex: u16 = 0;
        var numberIndex: u8 = 0;
        var operation = operations[0];
        for (writer.written(), 0..) |char, i| {
            if (i < operations.len and operations[i] != ' ' and i != 0) {
                _ = results.items[calculationIndex].pop();
                calculationIndex += 1;
                if (results.items.len == calculationIndex) {
                    try results.append(allocator, std.ArrayList(u64).empty);
                }
                numberIndex = 0;
                operation = operations[i];
            }

            const isSpace = char == ' ';
            const numberPart = if (isSpace) 0 else char - 48;
            if (results.items[calculationIndex].items.len != numberIndex) {
                const number = results.items[calculationIndex].items[numberIndex];
                const multiplier: u8 = if (isSpace) 1 else 10;
                results.items[calculationIndex].items[numberIndex] = number * multiplier + numberPart;
            } else {
                try results.items[calculationIndex].append(allocator, numberPart);
            }

            numberIndex += 1;
        }

        writer.clearRetainingCapacity();
        lineIndex += 1;
    } else |err| if (err != error.EndOfStream) return err;

    var calculationIndex: u16 = 0;
    var summedResult: u64 = 0;
    while (operationIterator.next()) |operation| {
        var result: u64 = results.items[calculationIndex].items[0];
        for (results.items[calculationIndex].items[1..]) |number| {
            result = try doOperation(operation[0], result, number);
        }
        summedResult += result;
        calculationIndex += 1;
    }

    return summedResult;
}

inline fn doOperation(operation: u8, left: u64, right: u64) !u64 {
    return switch (operation) {
        '*' => left * right,
        '+' => left + right,
        else => error.UnsupportedOperation,
    };
}

fn findOperations(reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !struct {[]u8, u8} {
    var numberLines: u8 = 0;
    while (reader.streamDelimiter(&writer.writer, '\n')) |_| {
        _ = reader.toss(1);

        const character = writer.written()[0];
        if (character != ' ' and (character < '0' or character > '9')) {
            const operations = try writer.toOwnedSlice();
            writer.clearRetainingCapacity();
            return .{ operations, numberLines };
        }

        numberLines += 1;
        writer.clearRetainingCapacity();
    } else |err| if (err != error.EndOfStream) return err;

    return error.OperationsNotFound;
}

test "passes example input (part 1)" {
    const input: []const u8 =
        \\123 328  51 64
        \\ 45 64  387 23
        \\  6 98  215 314
        \\*   +   *   +
        \\
    ;

    var reader = SeekableReader.fromFixed(input);
    try std.testing.expectEqual(4277556, solve_part1(&reader));
}

test "passes example input (part 2)" {
    const input: []const u8 =
        \\123 328  51 64
        \\ 45 64  387 23
        \\  6 98  215 314
        \\*   +   *   +
        \\
    ;

    var reader = SeekableReader.fromFixed(input);
    try std.testing.expectEqual(3263827, solve_part2(&reader));
}
