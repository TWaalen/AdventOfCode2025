const std = @import("std");

const RingBuffer = @This();

allocator: std.mem.Allocator,
// TODO(TW): Parameterize slot count.
slots: [3] struct {
    buffer: ?[]u8 = null,
    end: usize = 0,
},
len: usize = 0,
write_index: usize = 0,

pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!RingBuffer {
    return .{
        .allocator = allocator,
        .slots = .{ .{}, .{}, .{}, },
    };
}

pub fn deinit(self: *RingBuffer) void {
    for (self.slots, 0..) |slot, i| {
        if (slot.buffer != null) {
            self.allocator.free(slot.buffer.?);
            self.slots[i].buffer = null;
            self.slots[i].end = 0;
        }
    }
}

pub fn get(self: *RingBuffer, index: i8) ?[]u8 {
    const actualIndex: usize = @intCast(@mod(@as(i8, @intCast(self.write_index)) - index - 1, 3));

    const slot = self.slots[actualIndex];
    if (slot.buffer == null) { return null; }

    return slot.buffer.?[0..slot.end];
}

pub fn push(self: *RingBuffer, item: []const u8) error{OutOfMemory}!void {
    var writeSlot = self.slots[self.write_index];
    if (writeSlot.buffer != null) {
        if (writeSlot.buffer.?.len <= item.len) {
            @memcpy(writeSlot.buffer.?, item);
            writeSlot.end = item.len;
            self.write_index = @rem(self.write_index + 1, 3);
            return;
        }

        self.allocator.free(writeSlot.buffer.?);
        writeSlot.buffer = null;
        self.len -= 1;
    }

    self.slots[self.write_index].buffer = try self.allocator.dupe(u8, item);
    self.slots[self.write_index].end = item.len;
    self.write_index = @rem(self.write_index + 1, 3);
    self.len += 1;
}

test "test" {
    var ringBuffer = try RingBuffer.init(std.testing.allocator);
    defer ringBuffer.deinit();

    try std.testing.expectEqual(0, ringBuffer.len);

    const input = "TESTTESTTEST";
    {
        errdefer std.debug.print("input: {s}\n", .{input});
        try ringBuffer.push(input);
        try std.testing.expectEqualStrings(input, ringBuffer.get(0).?);
        try std.testing.expectEqual(1, ringBuffer.len);
    }

    const input2 = "TESTTEST";
    {
        errdefer std.debug.print("input: {s}\n", .{input2});
        try ringBuffer.push(input2);
        try std.testing.expectEqualStrings(input2, ringBuffer.get(0).?);
        try std.testing.expectEqualStrings(input, ringBuffer.get(1).?);
        try std.testing.expectEqual(2, ringBuffer.len);
    }

    const input3 = "TEST";
    {
        errdefer std.debug.print("input: {s}\n", .{input3});
        try ringBuffer.push(input3);
        try std.testing.expectEqualStrings(input3, ringBuffer.get(0).?);
        try std.testing.expectEqualStrings(input2, ringBuffer.get(1).?);
        try std.testing.expectEqualStrings(input, ringBuffer.get(2).?);
        try std.testing.expectEqual(3, ringBuffer.len);
    }

    const input4 = "TES";
    {
        errdefer std.debug.print("input: {s}\n", .{input4});
        try ringBuffer.push(input4);
        try std.testing.expectEqualStrings(input4, ringBuffer.get(0).?);
        try std.testing.expectEqualStrings(input3, ringBuffer.get(1).?);
        try std.testing.expectEqualStrings(input2, ringBuffer.get(2).?);
        try std.testing.expectEqual(3, ringBuffer.len);
    }
}
