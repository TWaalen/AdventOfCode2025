const std = @import("std");

const SeekableReader = @This();

const ReaderKind = enum {
    file,
    fixed,
};

const Reader = union(ReaderKind) {
    file: *std.fs.File.Reader,
    fixed: std.Io.Reader,
};

reader: Reader,

pub fn interface(self: *SeekableReader) *std.Io.Reader {
    return switch (self.reader) {
        .file => |r| &r.*.interface,
        .fixed => |*r| r,
    };
}

pub fn seekTo(self: *SeekableReader, seek: usize) !void {
    return switch(self.reader) {
        .file => |r| r.*.seekTo(seek),
        .fixed => |*r| {
            r.seek = seek;
            r.end = r.buffer.len;
        }
    };
}

pub fn fromFile(fileReader: *std.fs.File.Reader) SeekableReader {
    return .{
        .reader = .{
            .file = fileReader,
        },
    };
}

pub fn fromFixed(buffer: []const u8) SeekableReader {
    return .{
        .reader = .{
            .fixed = std.Io.Reader.fixed(buffer),
        },
    };
}

test "can seek (file)" {
    const file = try std.fs.cwd().openFile("inputs/day1", .{ .mode = .read_only });
    defer file.close();
    var reader_buf: [1024]u8 = undefined;
    var file_reader = file.reader(&reader_buf);

    var writer_buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&writer_buf);

    var seekable_reader = fromFile(&file_reader);
    try seekable_reader.interface().streamExact(&writer, 3);
    try std.testing.expectEqualStrings("R24", writer.buffered());
    _ = writer.consumeAll();
    try seekable_reader.seekTo(0);

    try seekable_reader.interface().streamExact(&writer, 1);
    try std.testing.expectEqualStrings("R", writer.buffered());
}

test "can seek (fixed)" {
    const input: []const u8 = "12345678";

    var writer_buf: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&writer_buf);

    var seekable_reader = fromFixed(input);
    try seekable_reader.interface().streamExact(&writer, 3);
    try std.testing.expectEqualStrings("123", writer.buffered());
    _ = writer.consumeAll();
    try seekable_reader.seekTo(0);

    try seekable_reader.interface().streamExact(&writer, 1);
    try std.testing.expectEqualStrings("1", writer.buffered());
    _ = writer.consumeAll();
    try seekable_reader.seekTo(6);
    try seekable_reader.interface().streamExact(&writer, 1);
    try std.testing.expectEqualStrings("7", writer.buffered());
}
