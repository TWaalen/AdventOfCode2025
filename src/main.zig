const SeekableReader = @import("utils/SeekableReader.zig");

const day1 = @import("day1.zig");
const day2 = @import("day2.zig");
const day3 = @import("day3.zig");
const day4 = @import("day4.zig");
const day5 = @import("day5.zig");
const day6 = @import("day6.zig");
const day7 = @import("day7.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.next();
    const day: i8 = if (args.next()) |a| try std.fmt.parseInt(i8, std.mem.sliceTo(a, 0), 10) else 1;
    const part: i8 = if (args.next()) |a| try std.fmt.parseInt(i8, std.mem.sliceTo(a, 0), 10) else 1;

    const filename = try std.fmt.allocPrintSentinel(alloc, "inputs/day{d}", .{day}, 0);
    defer alloc.free(filename);

    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    var read_buf: [1024]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    var seekable_reader = SeekableReader.fromFile(&file_reader);

    var writer = std.Io.Writer.Allocating.init(alloc);
    defer writer.deinit();

    std.debug.print("filename: {s}, day: {d}, part: {d}\n", .{ filename, day, part });
    const solution = try switch (day) {
        1 => day1.solve(part, &file_reader.interface, &writer),
        2 => day2.solve(part, &file_reader.interface, &writer),
        3 => day3.solve(part, &file_reader.interface, &writer),
        4 => day4.solve(part, &file_reader, &writer),
        5 => day5.solve(part, &file_reader.interface),
        6 => if (part == 1) day6.solve_part1(&seekable_reader) else day6.solve_part2(&seekable_reader),
        7 => if (part == 1) day7.solve_part1(&file_reader.interface, &writer) else day7.solve_part2(&file_reader.interface, &writer),
        else => error.NotImplemented,
    };
    std.debug.print("Solution: {d}\n", .{solution});
}

const std = @import("std");

comptime {
    _ = @import("utils/RingBuffer.zig");
    _ = @import("utils/SeekableReader.zig");
    _ = @import("day1.zig");
    _ = @import("day2.zig");
    _ = @import("day3.zig");
    _ = @import("day4.zig");
    _ = @import("day5.zig");
    _ = @import("day6.zig");
    _ = @import("day7.zig");
}
