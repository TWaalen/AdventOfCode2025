const std = @import("std");
const RingBuffer = @import("utils/RingBuffer.zig");

pub fn solve(part: i8, reader: *std.fs.File.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    if (part == 1) { return try solve_part1(&reader.*.interface, writer); }
    else if (part == 2) { return try solve_part2(reader, writer); }
    return error.NotImplemented;
}

fn solve_part1(reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var totalAccessibleRolls: u64 = 0;
    var ringBuffer = try RingBuffer.init(alloc);
    defer ringBuffer.deinit();
    while (true) {
        _ = reader.streamDelimiter(&writer.*.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1);

        try ringBuffer.push(writer.written());
        writer.*.clearRetainingCapacity();

        if (ringBuffer.len < 2) { continue; }
        totalAccessibleRolls += countAccessibleRollsInRow(ringBuffer.get(2), ringBuffer.get(1).?, ringBuffer.get(0));
    }

    totalAccessibleRolls += countAccessibleRollsInRow(ringBuffer.get(1), ringBuffer.get(0).?, null);

    return totalAccessibleRolls;
}

fn countAccessibleRollsInRow(previousRow: ?[]const u8, currentRow: []const u8, nextRow: ?[]const u8) u64 {
    var accessibleRolls: u64 = 0;
    for (0..currentRow.len) |cell| {
        if (currentRow[cell] != '@') { continue; }

        var adjacentRolls: u8 = 0;
        const adjacentStartIndex: u8 = if (cell != 0) 0 else 1;
        const adjacentEndIndex: u8 = if (cell != currentRow.len - 1) 3 else 2;

        for (adjacentStartIndex..adjacentEndIndex) |i| {
            if (previousRow != null and previousRow.?[cell + i - 1] == '@') {
                adjacentRolls += 1;
            }

            if (nextRow != null and nextRow.?[cell + i - 1] == '@') {
                adjacentRolls += 1;
            }
        }

        if (cell > 0 and currentRow[cell - 1] == '@') { adjacentRolls += 1; }
        if (cell + 1 < currentRow.len and currentRow[cell + 1] == '@') { adjacentRolls += 1; }

        if (adjacentRolls < 4) {
            accessibleRolls += 1;
        }
    }

    return accessibleRolls;
}

fn solve_part2(reader: *std.fs.File.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    const width, const height = try determineGridSize(reader);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const paperGrid: []u8 = try allocator.alloc(u8, height * width);
    defer allocator.free(paperGrid);
    @memset(paperGrid, 0);
    try fillGrid(&reader.*.interface, writer, paperGrid, width);

    var removableRolls: u64 = 0;

    while (true) {
        const result = removeAccessibleRollsInGrid(paperGrid, width, height);
        if (result == 0) { break; }
        removableRolls += result;
    }

    return removableRolls;
}

inline fn determineGridSize(reader: *std.fs.File.Reader) !struct { u64, u64 } {
    var width: u64 = 0;
    var height: u64 = 0;
    var buf = [_]u8 { 0 } ** 1024;
    var initialWriter = std.Io.Writer.Discarding.init(&buf);
    while (true) {
        _ = reader.*.interface.streamDelimiter(&initialWriter.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.*.interface.toss(1);
        if (width == 0) { width = initialWriter.writer.end; }
        height += 1;
    }

    try reader.*.seekTo(0);

    return .{ width, height };
}

inline fn fillGrid(reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating, grid: []u8, width: u64) !void {
    var rowStartIndex: usize = 0;
    while (true) {
        _ = reader.streamDelimiter(&writer.*.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1);

        for (writer.*.written(), 0..) |char, x| {
            if (char == '@') { grid[rowStartIndex + x] = 1; }
        }
        rowStartIndex += width;
        writer.*.clearRetainingCapacity();
    }
}

inline fn removeAccessibleRollsInGrid(grid: []u8, width: u64, height: u64) u64 {
    var removedRolls: u64 = 0;
    for (0..height) |y| {
        const isFirstRow = y == 0;
        const isLastRow = y == height - 1;
        const rowIndex = y * width;

        for (0..width) |x| {
            const currentCellIndex = rowIndex + x;
            if (grid[currentCellIndex] == 0) { continue; }

            var adjacentRolls: u8 = 0;

            const isStartOfRow = x == 0;
            const isEndOfRow = x == width - 1;

            // Previous row
            if (!isFirstRow) {
                adjacentRolls += checkAdjacentRolls(grid, currentCellIndex - width,
                    isStartOfRow, isEndOfRow);
            }

            // Current row
            if (!isStartOfRow) { adjacentRolls += grid[currentCellIndex - 1]; }
            if (!isEndOfRow) { adjacentRolls += grid[currentCellIndex + 1]; }

            // Next row
            if (!isLastRow) {
                adjacentRolls += checkAdjacentRolls(grid, currentCellIndex + width,
                    isStartOfRow, isEndOfRow);
            }

            if (adjacentRolls < 4) {
                grid[currentCellIndex] = 0;
                removedRolls += 1;
            }
        }
    }

    return removedRolls;
}

inline fn checkAdjacentRolls(grid: []const u8, cellIndex: usize, isStartOfRow: bool, isEndOfRow: bool) u8 {
    var adjacentRolls: u8 = 0;

    if (!isStartOfRow) { adjacentRolls += grid[cellIndex - 1]; }
    adjacentRolls += grid[cellIndex];
    if (!isEndOfRow) { adjacentRolls += grid[cellIndex + 1]; }

    return adjacentRolls;
}

test "count accessible rolls (part 1)" {
    const cases = [_] struct {
        input: struct {
            previousRow: ?[]u8,
            currentRow: []u8,
            nextRow: []u8,
        },
        expected: u64,
    }{
        .{
            .input = .{
                .previousRow = null,
                .currentRow = @constCast("..@@.@@@@."),
                .nextRow = @constCast("@@@.@.@.@@"),
            },
            .expected = 5,
        }, .{
            .input = .{
                .previousRow = @constCast("..@@.@@@@."),
                .currentRow = @constCast("@@@.@.@.@@"),
                .nextRow = @constCast("@@@@@.@.@@"),
            },
            .expected = 1,
        },
    };

    for (cases) |case| {
        errdefer std.debug.print("input:\n{any}\n{s}\n{s}\n", .{case.input.previousRow, case.input.currentRow, case.input.nextRow});
        const result = countAccessibleRollsInRow(case.input.previousRow, case.input.currentRow, case.input.nextRow);
        try std.testing.expectEqual(case.expected, result);
    }
}

test "example test" {
    const input = [_][]const u8 {
        "..@@.@@@@.",
        "@@@.@.@.@@",
        "@@@@@.@.@@",
        "@.@@@@..@.",
        "@@.@@@@.@@",
        ".@@@@@@@.@",
        ".@.@.@.@@@",
        "@.@@@.@@@@",
        ".@@@@@@@@.",
        "@.@.@@@.@.",
    };

    try std.testing.expectEqual(input, input);
}
