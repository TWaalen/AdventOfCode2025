const builtin = @import("builtin");
const std = @import("std");

var outputName: []const u8 = "grid.ppm";

const Point = [2]i32;
const PointList = std.ArrayListUnmanaged(Point);
const BoundingBox = struct {
    min: [2]usize,
    max: [2]usize
};

pub fn solve(part: i8, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var redTilePositions = try parseRedTilePositions(allocator, reader,writer );
    defer redTilePositions.deinit(allocator);

    if (part == 1) {
        return findLargestArea_part1(redTilePositions);
    } else if (part == 2) {
        return try findLargestArea_part2(allocator, redTilePositions);
    }

    return error.InvalidPart;
}

inline fn boundingBox(positions: PointList) BoundingBox {
    var minX: i32 = std.math.maxInt(i32);
    var minY: i32 = std.math.maxInt(i32);
    var maxX: i32 = 0;
    var maxY: i32 = 0;

    for (positions.items) |position| {
        if (position[0] < minX) { minX = position[0]; }
        if (position[0] > maxX) { maxX = position[0]; }
        if (position[1] < minY) { minY = position[1]; }
        if (position[1] > maxY) { maxY = position[1]; }
    }

    return BoundingBox {
        .min = [2]usize { @intCast(minX), @intCast(minY) },
        .max = [2]usize { @intCast(maxX), @intCast(maxY) }
    };
}

fn drawDebugOutput(allocator: std.mem.Allocator, polygon: PointList, edgeVertex1Index: usize, edgeVertex2Index: usize, checkCorner1: Point, checkCorner2: Point) !void {
    const bbox = boundingBox(polygon);
    const width: usize = @intCast(bbox.max[0] - bbox.min[0] + 1);
    const height: usize = @intCast(bbox.max[1] - bbox.min[1] + 1);
    const factor: usize = if (builtin.is_test) 1 else 100;
    const stride = (width / factor) * 3;

    const header = try std.fmt.allocPrint(allocator, "P6\n{d} {d}\n255\n", .{width / factor, height / factor});
    defer allocator.free(header);
    const grid = try allocator.alloc(u8, stride * (height / factor + 1));
    defer allocator.free(grid);
    @memset(grid, @as(u8, 0xFF));
    const edgeVertex1 = polygon.items[edgeVertex1Index];
    const edgeVertex2 = polygon.items[edgeVertex2Index];
    drawRectangle(grid, edgeVertex1, edgeVertex2, bbox.min, factor, stride);
    try drawPolygon(grid, polygon, bbox.min, factor, stride);
    drawPoint(grid, checkCorner1, bbox.min, factor, stride);
    drawPoint(grid, checkCorner2, bbox.min, factor, stride);

    const file = try std.fs.cwd().createFile(outputName, .{});
    defer file.close();

    var writer = file.deprecatedWriter();
    try writer.writeAll(header);
    try writer.writeAll(grid);
}

fn drawPoint(grid: []u8, point: Point, offset: [2]usize, factor: usize, stride: usize) void {
    const pointUnsigned = [2]usize { @intCast(point[0]), @intCast(point[1]) };
    const index = (pointUnsigned[0] - offset[0]) / factor * 3 + (pointUnsigned[1] - offset[1]) / factor * stride;
    grid[index + 0] = 0xFF;
    grid[index + 1] = 0x00;
    grid[index + 2] = 0xFF;
}

fn drawPolygon(grid: []u8, polygon: PointList, offset: [2]usize, factor: usize, stride: usize) !void {
    for (0..polygon.items.len) |i| {
        const vertex1 = polygon.items[i];
        const vertex2 = polygon.items[@mod(i + 1, polygon.items.len)];
        const vertex1u = [2]usize { @intCast(vertex1[0]), @intCast(vertex1[1]) };
        const vertex2u = [2]usize { @intCast(vertex2[0]), @intCast(vertex2[1]) };

        if (vertex1[0] == vertex2[0]) {
            const x = (vertex1u[0] - offset[0]) / factor;
            const y0 = (@min(vertex1u[1], vertex2u[1]) - offset[1]) / factor;
            const y1 = (@max(vertex1u[1], vertex2u[1]) - offset[1]) / factor;

            for (y0..y1 + 1) |y| {
                const index = x * 3 + y * stride;
                grid[index + 0] = 0x00;
                grid[index + 1] = 0x00;
                grid[index + 2] = 0xFF;
            }
        } else if (vertex1[1] == vertex2[1]) {
            const y = (vertex1u[1] - offset[1]) / factor;
            const x0 = (@min(vertex1u[0], vertex2u[0]) - offset[0]) / factor;
            const x1 = (@max(vertex1u[0], vertex2u[0]) - offset[0]) / factor;

            for (x0..x1 + 1) |x| {
                const index = x * 3 + y * stride;
                grid[index + 0] = 0x00;
                grid[index + 1] = 0x00;
                grid[index + 2] = 0xFF;
            }
        } else {
            return error.SlopedEdgeUnsupported;
        }

        var index = (vertex1u[0] - offset[0]) / factor * 3 + (vertex1u[1] - offset[1]) / factor * stride;
        grid[index + 0] = 0xFF;
        grid[index + 1] = 0x00;
        grid[index + 2] = 0x00;

        index = (vertex2u[0] - offset[0]) / factor * 3 + (vertex2u[1] - offset[1]) / factor * stride;
        grid[index + 0] = 0xFF;
        grid[index + 1] = 0x00;
        grid[index + 2] = 0x00;
    }
}

fn drawRectangle(grid: []u8, a: Point, b: Point, offset: [2]usize, factor: usize, stride: usize) void {
    const aUnsigned = [2]usize { @intCast(a[0]), @intCast(a[1]) };
    const bUnsigned = [2]usize { @intCast(b[0]), @intCast(b[1]) };
    const minX = (@min(aUnsigned[0], bUnsigned[0]) - offset[0]) / factor;
    const maxX = (@max(aUnsigned[0], bUnsigned[0]) - offset[0]) / factor;
    const minY = (@min(aUnsigned[1], bUnsigned[1]) - offset[1]) / factor;
    const maxY = (@max(aUnsigned[1], bUnsigned[1]) - offset[1]) / factor;

    for (minY..maxY + 1) |y| {
        for (minX..maxX + 1) |x| {
            const index = x * 3 + y * stride;
            grid[index + 0] = 0x00;
            grid[index + 1] = 0xFF;
            grid[index + 2] = 0x00;
        }
    }
}

inline fn findLargestArea_part1(points: PointList) u64 {
    var largestArea: u64 = 0;
    for (points.items, 0..) |position, i| {
        for (points.items[i + 1..]) |otherPosition| {
            const area = rectangleArea(position, otherPosition);
            if (area > largestArea) {
                largestArea = area;
            }
        }
    }

    return largestArea;
}

inline fn findLargestArea_part2(allocator: std.mem.Allocator, polygon: PointList) !u64 {
    var largestArea: u64 = 0;
    var edgeVertex1Index: usize = 0;
    var edgeVertex2Index: usize = 0;
    var checkCorner1: Point = undefined;
    var checkCorner2: Point = undefined;
    for (polygon.items, 0..) |point, i| {
        for (polygon.items[i + 1..], i + 1..) |otherPoint, j| {
            const area = rectangleArea(point, otherPoint);
            if (area <= largestArea) { continue; }

            const corner1 = Point { point[0], otherPoint[1] };
            const corner2 = Point { otherPoint[0], point[1] };
            // std.debug.print("Rectangle: ({d}, {d}), ({d}, {d}), ({d}, {d}), ({d}, {d})\n", .{point[0], point[1], otherPoint[0], otherPoint[1], corner1[0], corner1[1], corner2[0], corner2[1]});
            if (!isPointInPolygon(corner1, polygon) or
                !isPointInPolygon(corner2, polygon)) {
                continue;
            }

            if (corner1[1] == 20 or corner2[1] == 20) {
                // std.debug.print("Rectangle from ({d}, {d}) to ({d}, {d}) with area {d}\n", .{point[0], point[1], otherPoint[0], otherPoint[1], area});
                var result = isEdgeInPolygon(corner1, point, polygon);
                // std.debug.print("Edge from ({d}, {d}) to ({d}, {d}): {any}\n", .{corner1[0], corner1[1], point[0], point[1], result});
                result = isEdgeInPolygon(corner1, otherPoint, polygon);
                // std.debug.print("Edge from ({d}, {d}) to ({d}, {d}): {any}\n", .{corner1[0], corner1[1], otherPoint[0], otherPoint[1], result});
                result = isEdgeInPolygon(corner2, point, polygon);
                // std.debug.print("Edge from ({d}, {d}) to ({d}, {d}): {any}\n", .{corner2[0], corner2[1], point[0], point[1], result});
                result = isEdgeInPolygon(corner2, otherPoint, polygon);
                // std.debug.print("Edge from ({d}, {d}) to ({d}, {d}): {any}\n", .{corner2[0], corner2[1], otherPoint[0], otherPoint[1], result});
            }

            if (!isEdgeInPolygon(corner1, point, polygon) or
                !isEdgeInPolygon(corner1, otherPoint, polygon) or
                !isEdgeInPolygon(corner2, point, polygon) or
                !isEdgeInPolygon(corner2, otherPoint, polygon)) {
                continue;
            }

            // std.debug.print("Rectangle from ({d}, {d}) to ({d}, {d}) with area {d} > {d}\n", .{point[0], point[1], otherPoint[0], otherPoint[1], area, largestArea});
            edgeVertex1Index = i;
            edgeVertex2Index = j;
            checkCorner1 = corner1;
            checkCorner2 = corner2;
            largestArea = area;
        }
    }

    try drawDebugOutput(allocator, polygon, edgeVertex1Index, edgeVertex2Index,
        checkCorner1, checkCorner2);

    return largestArea;
}

inline fn isPointInBoundingBox(p: Point, bbox: BoundingBox) bool {
    return p[0] >= bbox.min[0] and p[0] <= bbox.max[0] and p[1] >= bbox.min[1] and p[1] <= bbox.max[1];
}

// TW: A prerequisite for this algorithm is that point A and point B have
// already been validated to be inside the polygon. Just as `isPointInPolygon`
// this does a kind of ray cast, but then in the direction of the edge instead
// of always to the right. If there are less than 2 intersections that means
// the edge is in the polygon, excluding the left/topmost point on the edge, so
// that it is possible for an edge to edge spanning edge to be considered in
// the polygon.
inline fn isEdgeInPolygon(a: Point, b: Point, polygon: PointList) bool {
    var intersectionCount: usize = 0;
    if (a[0] == b[0]) { // Vertical
        const minEdgeY = @min(a[1], b[1]);
        const maxEdgeY = @max(a[1], b[1]);

        const edgeX = a[0];
        for (polygon.items, 0..) |vertex1, i| {
            const vertex2 = polygon.items[@mod(i + 1, polygon.items.len)];
            if (vertex1[0] == vertex2[0]) { continue; } // Skip vertical edges

            const polygonEdgeY = vertex1[1];
            const minPolygonEdgeX = @min(vertex1[0], vertex2[0]);
            const maxPolygonEdgeX = @max(vertex1[0], vertex2[0]);
            if (maxEdgeY == 20) {
                // std.debug.print("Vertex1 = ({d}, {d})\n", .{vertex1[0], vertex1[1]});
                // std.debug.print("Vertex2 = ({d}, {d})\n", .{vertex2[0], vertex2[1]});
                // std.debug.print("({d} <= {d} and {d} <= {d}) and\n({d} < {d} and {d} < {d})\n",
                    // .{minEdgeY, polygonEdgeY, polygonEdgeY, maxEdgeY, minPolygonEdgeX, edgeX, edgeX, maxPolygonEdgeX});
            }
            if ((minEdgeY <= polygonEdgeY and polygonEdgeY < maxEdgeY) and
                (minPolygonEdgeX <= edgeX and edgeX < maxPolygonEdgeX)) {
                intersectionCount += 1;
            }
        }
    } else if (a[1] == b[1]) { // Horizontal
        const minEdgeX = @min(a[0], b[0]);
        const maxEdgeX = @max(a[0], b[0]);
        const edgeY = a[1];

        for (polygon.items, 0..) |vertex1, i| {
            const vertex2 = polygon.items[@mod(i + 1, polygon.items.len)];
            if (vertex1[1] == vertex2[1]) { continue; } // Skip horizontal edges

            const polygonEdgeX = vertex1[0];
            const minPolygonEdgeY = @min(vertex1[1], vertex2[1]);
            const maxPolygonEdgeY = @max(vertex1[1], vertex2[1]);
            // if (leftPoint[0] == 2 and leftPoint[1] == 20 and rightPoint[0] == 18 and rightPoint[1] == 20) {
            //     std.debug.print("Vertex1 = ({d}, {d})\n", .{vertex1[0], vertex1[1]});
            //     std.debug.print("Vertex2 = ({d}, {d})\n", .{vertex2[0], vertex2[1]});
            //     std.debug.print("({d} < {d} and {d} <= {d}) and\n({d} <= {d} and {d} <= {d})\n",
            //         .{leftPoint[0], polygonEdgeX, polygonEdgeX, rightPoint[0], vertex1[1], edgeY, edgeY, vertex2[1]});
            // }
            if ((minEdgeX <= polygonEdgeX and polygonEdgeX < maxEdgeX) and
                (minPolygonEdgeY <= edgeY and edgeY < maxPolygonEdgeY)) {
                intersectionCount += 1;
            }
        }
    }

    return intersectionCount <= 1;
}

// TW: This uses the ray casting algorithm modified with a collinearity & on
// edge check to determine if a point is in the polygon. The ray casting
// algorithm considers a point to be in the polygon if the ray hits an odd
// count of polygon edges. This however excludes points directly on the edge
// of the polygon in certain cases, which is handled by first checking if the
// point is collinear with the edge & then if it is actually within the edge
// bounds.
//
// The intersection check is also simplified based on that there are only
// vertical and horizontal edges. Only a vertical edge will reach the
// intersection check, and as such there is no need to calculate the
// intersection point, the intersection will always be at the X coordinate
// of the edge.
inline fn isPointInPolygon(p: Point, polygon: PointList) bool {
    var intersectionCount: u64 = 0;
    for (polygon.items, 0..) |vertex1, i| {
        const vertex2 = polygon.items[@mod(i + 1, polygon.items.len)];
        const v1p = [2]i64 { p[0] - vertex1[0], p[1] - vertex1[1] };
        const v1v2 = [2]i64 { vertex2[0] - vertex1[0], vertex2[1] - vertex1[1] };
        const cross = v1p[0] * v1v2[1] - v1p[1] * v1v2[0];
        if (cross == 0) {
            // TW: Point is collinear, check if point is on edge.
            if ((@min(vertex1[0], vertex2[0]) <= p[0] and p[0] <= @max(vertex1[0], vertex2[0])) and
                (@min(vertex1[1], vertex2[1]) <= p[1] and p[1] <= @max(vertex1[1], vertex2[1]))) {
                return true;
            }
        }

        if ((vertex1[1] > p[1]) != (vertex2[1] > p[1]) and vertex1[0] > p[0]) {
            intersectionCount += 1;
        }
    }

    return @mod(intersectionCount, 2) == 1;
}

fn parseRedTilePositions(allocator: std.mem.Allocator, reader: *std.Io.Reader, writer: *std.Io.Writer.Allocating) !PointList {
    var positions = PointList.empty;
    while (reader.streamDelimiter(&writer.*.writer, '\n')) |_| : ({
        _ = reader.toss(1);
        writer.*.clearRetainingCapacity();
    }) {
        try positions.append(allocator, try parseVector(writer.*.written()));
    } else |err| if (err != error.EndOfStream) return err;

    return positions;
}

inline fn parseVector(line: []const u8) ![2]i32 {
    var splitIterator = std.mem.splitScalar(u8, line, ',');
    var vector: [2]i32 = undefined;
    var componentIndex: usize = 0;
    while (splitIterator.next()) |split| {
        if (componentIndex >= 2) { return error.TooManyComponents; }

        vector[componentIndex] = try std.fmt.parseInt(i32, split, 10);

        componentIndex += 1;
    }

    if (componentIndex < 2) { return error.NotEnoughComponents; }

    return vector;
}

inline fn rectangleArea(a: [2]i32, b: [2]i32) u64 {
    const xLength: u64 = @abs(a[0] - b[0]) + 1;
    const yLength: u64 = @abs(a[1] - b[1]) + 1;

    return xLength * yLength;
}

test "passes example input" {
    const input: [] const u8 =
        \\7,1
        \\11,1
        \\11,7
        \\9,7
        \\9,5
        \\2,5
        \\2,3
        \\7,3
        \\
    ;

    outputName = "grid_example.ppm";
    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();
    try std.testing.expectEqual(50, solve(1, &reader, &writer));
    reader.seek = 0;
    reader.end = input.len;
    try std.testing.expectEqual(24, solve(2, &reader, &writer));
}

test "works for concave polygons (1)" {
    const input: []const u8 =
        \\2,2
        \\28,2
        \\28,20
        \\18,20
        \\18,10
        \\13,10
        \\13,20
        \\2,20
        \\
    ;

    outputName = "grid_concave1.ppm";
    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();
    try std.testing.expectEqual(513, solve(1, &reader, &writer));
    reader.seek = 0;
    reader.end = input.len;
    // try std.testing.expectEqual(228, solve(2, &reader, &writer));
}

test "works for concave polygons (2)" {
    const input: []const u8 =
        \\2,2
        \\28,2
        \\28,20
        \\2,20
        \\2,18
        \\10,18
        \\10,13
        \\2,13
        \\
    ;

    outputName = "grid_concave2.ppm";
    var reader = std.Io.Reader.fixed(input);
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();
    try std.testing.expectEqual(513, solve(1, &reader, &writer));
    reader.seek = 0;
    reader.end = input.len;
    try std.testing.expectEqual(324, solve(2, &reader, &writer));
}
