const std = @import("std");

const Vector3i = @This();

components: [3]i32,

pub fn init(x: i32, y: i32, z: i32) Vector3i {
    return Vector3i{ .components = .{ x, y, z } };
}

pub fn squareDistance(self: *const Vector3i, other: Vector3i) u64 {
    const distX: u64 = @abs(self.*.components[0] - other.components[0]);
    const distY: u64 = @abs(self.*.components[1] - other.components[1]);
    const distZ: u64 = @abs(self.*.components[2] - other.components[2]);
    const result: u64 = distX * distX + distY * distY + distZ * distZ;

    return result;
}

test squareDistance {
    const allZeros = Vector3i.init(0, 0, 0);
    const largePositive = Vector3i.init(28971, 2922, 56963);
    const largerPositive = Vector3i.init(25850, 58016, 47709);

    try std.testing.expectEqual(4092640294, allZeros.squareDistance(largePositive));
    try std.testing.expectEqual(6310227437, allZeros.squareDistance(largerPositive));
}