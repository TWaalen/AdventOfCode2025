const day1 = @import("day1.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.next();
    const filename = if (args.next()) |a| std.mem.sliceTo(a, 0) else "input";
    const day: i8 = if (args.next()) |a| try std.fmt.parseInt(i8, std.mem.sliceTo(a, 0), 10) else 1;
    const part: i8 = if (args.next()) |a| try std.fmt.parseInt(i8, std.mem.sliceTo(a, 0), 10) else 1;

    std.debug.print("filename: {s}, day: {d}, part: {d}\n", .{ filename, day, part });
    if (day == 1) {
        var executeDialTurn: *const fn (dialIndex: i16, password: i16, delta: i16) error{NotImplemented}!day1.DialTurnResult = undefined;
        if (part == 1) { executeDialTurn = day1.executeDialTurn_part1; }
        else if (part == 2) { executeDialTurn = day1.executeDialTurn_part2; }

        const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
        defer file.close();

        var read_buf: [1024]u8 = undefined;
        var file_reader = file.reader(&read_buf);
        const reader = &file_reader.interface;

        var line = std.Io.Writer.Allocating.init(alloc);
        defer line.deinit();

        var password: i16 = 0;
        var dialIndex: i16 = 50;
        while(true) {
            _ = reader.streamDelimiter(&line.writer, '\n') catch |err| {
                if (err == error.EndOfStream) break else return err;
            };
            _ = reader.toss(1);

            const delta = try day1.parseDialTurn(line.written());

            const result = try executeDialTurn(dialIndex, password, delta);
            dialIndex = result.dialIndex;
            password = result.password;

            line.clearRetainingCapacity();
        }

        std.debug.print("Password: {d}\n", .{password});
    }
}

const std = @import("std");

comptime {
    _ = @import("day1.zig");
}
