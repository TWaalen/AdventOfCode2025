const std = @import("std");
const SeekableReader = @import("utils/SeekableReader.zig");

pub fn solve(reader: *SeekableReader) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    const operations = try findOperations(reader.interface(), &writer);
    defer allocator.free(operations);
    var operationIterator = std.mem.tokenizeScalar(u8, operations, ' ');

    var results = std.ArrayList(u64).empty;
    defer results.deinit(allocator);

    try reader.seekTo(0);

    while (reader.interface().streamDelimiter(&writer.writer, '\n')) |_| {
        _ = reader.interface().toss(1);

        if (results.items.len == 0) {
            var numberIterator = std.mem.tokenizeScalar(u8, writer.written(), ' ');
            while (numberIterator.next()) |numberSlice| {
                try results.append(allocator, try std.fmt.parseInt(u64, numberSlice, 10));
            }

            writer.clearRetainingCapacity();
            continue;
        }

        if (writer.written()[0] < '0' or writer.written()[0] > '9') { break; }

        var numberIterator = std.mem.tokenizeScalar(u8, writer.written(), ' ');

        var i: usize = 0;
        while (numberIterator.next()) |numberSlice| {
            if (i >= results.items.len) { return error.NumberMismatch;}
            const operationSlice = operationIterator.next() orelse return error.MissingOperation;
            const number = try std.fmt.parseInt(u64, numberSlice, 10);

            switch (operationSlice[0]) {
                '*' => results.items[i] *= number,
                '+' => results.items[i] += number,
                else => return error.UnsupportedOperation,
            }
            i += 1;
        }
        operationIterator.reset();

        writer.clearRetainingCapacity();
    } else |err| if (err != error.EndOfStream) return err;

    var summedResults: u64 = 0;
    for (results.items) |result| {
        summedResults += result;
    }

    return summedResults;
}

fn findOperations(reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) ![] u8 {
    while (reader.streamDelimiter(&writer.writer, '\n')) |_| {
        _ = reader.toss(1);

        if (writer.written()[0] < '0' or writer.written()[0] > '9') {
            const operations = writer.toOwnedSlice();
            writer.clearRetainingCapacity();
            return operations;
        }

        writer.clearRetainingCapacity();
    } else |err| if (err != error.EndOfStream) return err;

    return error.OperationsNotFound;
}

test "passes example input" {
    const input: []const u8 =
        \\123 328  51 64
        \\45 64  387 23
        \\6 98  215 314
        \\*   +   *   +
        \\
    ;

    var reader = SeekableReader.fromFixed(input);
    try std.testing.expectEqual(4277556, solve(&reader));
}