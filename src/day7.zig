const std = @import("std");

pub fn solve_part1(reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    _ = try reader.streamDelimiter(&writer.*.writer, '\n');
    _ = reader.toss(1);
    const beamStartIndex = std.mem.indexOfScalar(u8, writer.*.written(), 'S').?;

    var bitSet = try std.DynamicBitSet.initEmpty(allocator, writer.*.written().len);
    defer bitSet.deinit();
    bitSet.set(beamStartIndex);
    writer.*.clearRetainingCapacity();

    var splitCount: u16 = 0;
    while (reader.streamDelimiter(&writer.*.writer, '\n')) |_| {
        _ = reader.toss(1);
        var searchPosition = bitSet.findFirstSet().?;
        while (std.mem.indexOfScalarPos(u8, writer.*.written(), searchPosition, '^')) |splitterIndex| {
            if (bitSet.isSet(splitterIndex)) {
                bitSet.set(splitterIndex - 1);
                bitSet.unset(splitterIndex);
                bitSet.set(splitterIndex + 1);
                splitCount += 1;
            }

            searchPosition = splitterIndex + 1;
        }

        writer.*.clearRetainingCapacity();
    } else |err| if (err != error.EndOfStream) return err;

    return splitCount;
}

pub fn solve_part2(reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    _ = try reader.streamDelimiter(&writer.*.writer, '\n');
    _ = reader.toss(1);
    const beamStartIndex = std.mem.indexOfScalar(u8, writer.*.written(), 'S').?;

    var beamMap = std.AutoHashMapUnmanaged(usize, u64).empty;
    defer beamMap.deinit(allocator);
    try beamMap.put(allocator, beamStartIndex, 1);
    writer.*.clearRetainingCapacity();

    while (reader.streamDelimiter(&writer.*.writer, '\n')) |_| {
        _ = reader.toss(1);
        var searchPosition: usize = 0;
        while (std.mem.indexOfScalarPos(u8, writer.*.written(), searchPosition, '^')) |splitterIndex| {
            const possiblePathsToSplitter = beamMap.fetchRemove(splitterIndex);
            if (possiblePathsToSplitter != null) {
                const leftBeam = beamMap.getOrPutAssumeCapacity(splitterIndex - 1);
                if (leftBeam.found_existing) {
                    leftBeam.value_ptr.* += possiblePathsToSplitter.?.value;
                } else {
                    leftBeam.value_ptr.* = possiblePathsToSplitter.?.value;
                }

                const rightBeam = try beamMap.getOrPut(allocator, splitterIndex + 1);
                if (rightBeam.found_existing) {
                    rightBeam.value_ptr.* += possiblePathsToSplitter.?.value;
                } else {
                    rightBeam.value_ptr.* = possiblePathsToSplitter.?.value;
                }
            }

            searchPosition = splitterIndex + 1;
        }

        writer.*.clearRetainingCapacity();
    } else |err| if (err != error.EndOfStream) return err;

    var possiblePaths: u64 = 0;
    var beamMapIterator = beamMap.valueIterator();
    while (beamMapIterator.next()) |possiblePathsToPoint| {
        possiblePaths += possiblePathsToPoint.*;
    }

    return possiblePaths;
}

test "passes example input (part 1)" {
    const input: []const u8 =
        \\.......S.......
        \\.......|.......
        \\.......^.......
        \\...............
        \\......^.^......
        \\...............
        \\.....^.^.^.....
        \\...............
        \\....^.^...^....
        \\...............
        \\...^.^...^.^...
        \\...............
        \\..^...^.....^..
        \\...............
        \\.^.^.^.^.^...^.
        \\...............
        \\
    ;

    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();
    try std.testing.expectEqual(21, solve_part1(&reader, &writer));
}

test "passes example input (part 2)" {
    const input: []const u8 =
        \\.......S.......
        \\.......|.......
        \\.......^.......
        \\...............
        \\......^.^......
        \\...............
        \\.....^.^.^.....
        \\...............
        \\....^.^...^....
        \\...............
        \\...^.^...^.^...
        \\...............
        \\..^...^.....^..
        \\...............
        \\.^.^.^.^.^...^.
        \\...............
        \\
    ;

    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();
    try std.testing.expectEqual(40, solve_part2(&reader, &writer));
}