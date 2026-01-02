const std = @import("std");
const Vector3i = @import("utils/Vector3i.zig");

const JunctionBoxList = std.ArrayListUnmanaged(Vector3i);
const JunctionBoxPair = struct {
    distance: u64,
    junctionBox1: usize,
    junctionBox2: usize,
};
const Circuit = std.ArrayListUnmanaged(usize);
const CircuitList = std.ArrayListUnmanaged(Circuit);

fn sortJunctionBoxPair(_: void, lhs: JunctionBoxPair, rhs: JunctionBoxPair) bool {
    return (comptime std.sort.asc(u64))({}, lhs.distance, rhs.distance);
}

pub fn solve(part: i8, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating, limiter: usize) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var junctionBoxes = try parseJunctionBoxes(allocator, reader, writer);
    defer junctionBoxes.deinit(allocator);

    var pairs = try collectPairs(allocator, junctionBoxes);
    defer pairs.deinit(allocator);

    var circuits = CircuitList.empty;
    defer {
        for (0..circuits.items.len) |i| {
            circuits.items[i].deinit(allocator);
        }
        circuits.deinit(allocator);
    }

    if (part == 1) {
        for (pairs.items, 0..) |pair, i| {
            if (i == limiter) { break; }

            try connectJunctionBoxPair(allocator, pair, &circuits);
        }

        return calculateAnswer_part1(circuits);
    } else if (part == 2) {
        for (pairs.items) |pair| {
            try connectJunctionBoxPair(allocator, pair, &circuits);
            
            if (circuits.items.len == 1 and circuits.items[0].items.len == junctionBoxes.items.len) {
                return std.math.cast(u64, junctionBoxes.items[pair.junctionBox1].components[0]).? *
                    std.math.cast(u64, junctionBoxes.items[pair.junctionBox2].components[0]).?;
            }
        }
    }

    return error.InvalidPart;
}

fn calculateAnswer_part1(circuits: CircuitList) u64 {
    var top3CircuitLengths: [3]usize = .{ 0 } ** 3;
    for (circuits.items) |circuit| {
        if (circuit.items.len > top3CircuitLengths[0]) {
            top3CircuitLengths[2] = top3CircuitLengths[1];
            top3CircuitLengths[1] = top3CircuitLengths[0];
            top3CircuitLengths[0] = circuit.items.len;
        } else if (circuit.items.len > top3CircuitLengths[1]) {
            top3CircuitLengths[2] = top3CircuitLengths[1];
            top3CircuitLengths[1] = circuit.items.len;
        } else if (circuit.items.len > top3CircuitLengths[2]) {
            top3CircuitLengths[2] = circuit.items.len;
        }
    }

    return top3CircuitLengths[0] * top3CircuitLengths[1] * top3CircuitLengths[2];
}

fn collectPairs(allocator: std.mem.Allocator, junctionBoxes: JunctionBoxList) !std.ArrayListUnmanaged(JunctionBoxPair) {
    var junctionPairs = std.ArrayListUnmanaged(JunctionBoxPair).empty;
    for (junctionBoxes.items, 0..) |junctionBox1, i| {
        for (junctionBoxes.items[i + 1..], i + 1..) |junctionBox2, j| {
            try junctionPairs.append(allocator, .{
                .distance = junctionBox1.squareDistance(junctionBox2),
                .junctionBox1 = i,
                .junctionBox2 = j,
            });
        }
    }

    std.mem.sort(JunctionBoxPair, junctionPairs.items, {}, sortJunctionBoxPair);
    return junctionPairs;
}

fn connectJunctionBoxPair(allocator: std.mem.Allocator, pair: JunctionBoxPair, circuits: *CircuitList) !void {
    const circuit1 = findCircuitContainingJunctionBox(circuits, pair.junctionBox1);
    const circuit2 = findCircuitContainingJunctionBox(circuits, pair.junctionBox2);

    if (circuit1 != null and circuit2 != null) {
        if (circuit1 == circuit2) { return; }

        try circuits.items[circuit1.?].appendSlice(allocator, circuits.items[circuit2.?].items);
        var circuit = circuits.swapRemove(circuit2.?);
        circuit.deinit(allocator);
    } else if (circuit1 != null) {
        try circuits.items[circuit1.?].append(allocator, pair.junctionBox2);
    } else if (circuit2 != null) {
        try circuits.items[circuit2.?].append(allocator, pair.junctionBox1);
    } else {
        var newCircuit = Circuit.empty;
        try newCircuit.append(allocator, pair.junctionBox1);
        try newCircuit.append(allocator, pair.junctionBox2);
        try circuits.append(allocator, newCircuit);
    }
}

fn findCircuitContainingJunctionBox(circuits: *CircuitList, junctionBox: usize) ?usize {
    for (circuits.items, 0..) |circuit, i| {
        if (std.mem.containsAtLeastScalar(usize, circuit.items, 1, junctionBox)) {
            return i;
        }
    }

    return null;
}

fn parseJunctionBoxes(allocator: std.mem.Allocator, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !JunctionBoxList {
    var junctionBoxes = JunctionBoxList.empty;
    while (reader.streamDelimiter(&writer.*.writer, '\n')) |_| {
        _ = reader.toss(1);
        try junctionBoxes.append(allocator, try parseVector(writer.*.written()));
        writer.*.clearRetainingCapacity();
    } else |err| if (err != error.EndOfStream) return err;

    return junctionBoxes;
}

inline fn parseVector(line: []const u8) !Vector3i {
    var splitIterator = std.mem.splitScalar(u8, line, ',');
    var vector = Vector3i { .components = undefined };
    var componentIndex: usize = 0;
    while (splitIterator.next()) |split| {
        if (componentIndex >= 3) { return error.TooManyComponents; }

        vector.components[componentIndex] = try std.fmt.parseInt(i32, split, 10);

        componentIndex += 1;
    }

    if (componentIndex < 3) { return error.NotEnoughComponents; }

    return vector;
}

test parseVector {
    const cases = [_] struct {
        input: []const u8,
        expected: Vector3i,
    }{
        .{ .input = "162,817,812", .expected = Vector3i.init(162, 817, 812) },
    };

    for (cases) |case| {
        errdefer std.debug.print("input: {s}\n", .{case.input});
        const result = parseVector(case.input);
        try std.testing.expectEqual(case.expected, result);
    }

    try std.testing.expectError(error.NotEnoughComponents, parseVector("162,817"));
    try std.testing.expectError(error.TooManyComponents, parseVector("162,817,812,542"));
}

test "passes example input" {
    const input: []const u8 =
        \\162,817,812
        \\57,618,57
        \\906,360,560
        \\592,479,940
        \\352,342,300
        \\466,668,158
        \\542,29,236
        \\431,825,988
        \\739,650,466
        \\52,470,668
        \\216,146,977
        \\819,987,18
        \\117,168,530
        \\805,96,715
        \\346,949,466
        \\970,615,88
        \\941,993,340
        \\862,61,35
        \\984,92,344
        \\425,690,689
        \\
    ;

    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();
    try std.testing.expectEqual(40, solve(1, &reader, &writer, 10));
    reader.seek = 0;
    reader.end = input.len;
    try std.testing.expectEqual(25272, solve(2, &reader, &writer, 10));
}
