const std = @import("std");

// for a position (x,y)
// if its a 0 height
// search upwards towards peaks
// possibly cache progress
//

const Position = struct {
    x: i32,
    y: i32,
    fn init(x: i32, y: i32) Position {
        return .{ .x = x, .y = y };
    }
};

const RectMap = struct {
    allocator: std.mem.Allocator,
    map: *std.AutoHashMap(Position, u8),
    width: usize,
    height: usize,

    fn init(allocator: std.mem.Allocator, width: usize) !RectMap {
        const map = try allocator.create(std.AutoHashMap(Position, u8));
        map.* = std.AutoHashMap(Position, u8).init(allocator);

        return .{ .allocator = allocator, .map = map, .width = width, .height = 0 };
    }

    fn add_row(self: *RectMap, row: []const u8) !void {
        for (0..row.len) |x| {
            const position = Position.init(@intCast(x), @intCast(self.height));
            try self.map.put(position, row[x] - 48);
        }
        self.height += 1;
    }

    fn valid_neighbours(self: *RectMap, pos: Position, res: []?Position) void {
        if (pos.y > 0) {
            res[0] = Position.init(pos.x, pos.y - 1);
        } else {
            res[0] = null;
        }
        if (pos.x < self.width - 1) {
            res[1] = Position.init(pos.x + 1, pos.y);
        } else {
            res[1] = null;
        }
        if (pos.y < self.height - 1) {
            res[2] = Position.init(pos.x, pos.y + 1);
        } else {
            res[2] = null;
        }
        if (pos.x > 0) {
            res[3] = Position.init(pos.x - 1, pos.y);
        } else {
            res[3] = null;
        }
    }

    fn dfs(self: *RectMap, start: Position) !usize {
        var neighbours = [4]?Position{ null, null, null, null };
        var found = std.AutoHashMap(Position, bool).init(self.allocator);
        var frontier = std.ArrayList(Position).init(self.allocator);
        try frontier.append(start);
        while (frontier.items.len > 0) {
            const explore = frontier.pop();
            const height = self.map.get(explore).?;
            self.valid_neighbours(explore, &neighbours);
            // std.log.info("explore {d},{d} h:{d} neighbours: {any} frontier: {any}", .{ explore.x, explore.y, height, neighbours, frontier.items });
            for (0..neighbours.len) |i| {
                if (neighbours[i] == null) {
                    continue;
                }
                const neighbour_height = self.map.get(neighbours[i].?).?;
                if (neighbour_height == 9 and height == 8) {
                    try found.put(neighbours[i].?, true);
                }
                if (neighbour_height != 0 and neighbour_height - 1 == height) {
                    try frontier.append(neighbours[i].?);
                }
            }
        }
        return @intCast(found.count());
    }

    fn dfs_permutations(self: *RectMap, start: Position) !u128 {
        var neighbours = [4]?Position{ null, null, null, null };
        var found = std.AutoHashMap(Position, u32).init(self.allocator);
        var frontier = std.ArrayList(Position).init(self.allocator);
        try frontier.append(start);
        while (frontier.items.len > 0) {
            const explore = frontier.pop();
            const height = self.map.get(explore).?;
            self.valid_neighbours(explore, &neighbours);
            for (0..neighbours.len) |i| {
                if (neighbours[i] == null) {
                    continue;
                }
                const neighbour_height = self.map.get(neighbours[i].?).?;
                if (neighbour_height == 9 and height == 8) {
                    var prev_found: u32 = 0;
                    if (found.get(neighbours[i].?)) |val| {
                        prev_found = val;
                    }
                    try found.put(neighbours[i].?, prev_found + 1);
                }
                if (neighbour_height != 0 and neighbour_height - 1 == height) {
                    try frontier.append(neighbours[i].?);
                }
            }
        }
        var res: u128 = 0;
        var iter = found.valueIterator();
        var next = iter.next();
        while (next != null) {
            res += @intCast(next.?.*);
            next = iter.next();
        }
        return res;
    }

    fn print_map(self: *RectMap) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.writeByte('\n');
        for (0..self.height) |row| {
            for (0..self.width) |col| {
                const pos = Position.init(@intCast(col), @intCast(row));
                if (self.map.get(pos)) |height| {
                    try stdout.writeByte(height + 48);
                }
            }
            try stdout.writeByte('\n');
        }
        try stdout.writeByte('\n');
    }
};

const file_path = "demo.txt";
const file_size = 26000; //15856;

pub fn main() !void {
    var o: std.os.linux.timespec = .{ .tv_sec = 0, .tv_nsec = 0 };
    var exit_code = std.os.linux.clock_gettime(std.os.linux.CLOCK.REALTIME, &o);
    if (exit_code != 0) {
        std.log.err("Failed syscall clock_gettime exit code {d}", .{exit_code});
        return;
    }
    const start = o;
    const f = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        std.log.info("hmm: {}", .{err});
        return;
    };
    defer f.close();

    var buf_reader = std.io.bufferedReader(f.reader());
    const in_stream = buf_reader.reader();
    var big_buf = std.mem.zeroes([file_size]u8);
    _ = in_stream.readAll(&big_buf) catch {};

    exit_code = std.os.linux.clock_gettime(std.os.linux.CLOCK.REALTIME, &o);
    if (exit_code != 0) {
        std.log.err("Failed syscall clock_gettime exit code {d}", .{exit_code});
        return;
    }
    const end = std.mem.indexOf(u8, &big_buf, "\x00").?;
    const post_load = o;
    const res = work(big_buf[0 .. end + 1]) catch |err| {
        std.log.info("whops {any}", .{err});
        return;
    };

    exit_code = std.os.linux.clock_gettime(std.os.linux.CLOCK.REALTIME, &o);
    if (exit_code != 0) {
        std.log.err("Failed syscall clock_gettime exit code {d}", .{exit_code});
        return;
    }
    const nano_diff = o.tv_nsec - start.tv_nsec + (o.tv_sec - start.tv_sec) * 1000000000;
    const nano_diff_load = o.tv_nsec - post_load.tv_nsec + (o.tv_sec - post_load.tv_sec) * 1000000000;
    if (@divTrunc(nano_diff, 1000000) == 0) {
        std.log.info("Since start: {d}.{d} μs", .{ @mod(@divTrunc(nano_diff, 1000), 1000), @mod(nano_diff, 1000) });
    } else {
        std.log.info("Since start: {d} {d}.{d} μs", .{ @divTrunc(nano_diff, 1000000), @mod(@divTrunc(nano_diff, 1000), 1000), @mod(nano_diff, 1000) });
    }
    if (@divTrunc(nano_diff_load, 1000000) == 0) {
        std.log.info("Since load:  {d}.{d} μs", .{ @mod(@divTrunc(nano_diff_load, 1000), 1000), @mod(nano_diff_load, 1000) });
    } else {
        std.log.info("Since load:  {d} {d}.{d} μs", .{ @divTrunc(nano_diff_load, 1000000), @mod(@divTrunc(nano_diff_load, 1000), 1000), @mod(nano_diff_load, 1000) });
    }
    var b: [100]u8 = undefined;
    const s = try std.fmt.bufPrint(&b, "{d},{d}\n", .{ res[0], res[1] });
    const stdout = std.io.getStdOut().writer();
    _ = try stdout.write(s);
}

fn work(data: []const u8) ![2]u128 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var map: ?RectMap = null;

    var i: usize = 0;
    var line_start: usize = 0;
    while (i < data.len) {
        if (data[i] == '\n' or data[i] == '\x00') {
            if (map == null) {
                map = try RectMap.init(allocator, i);
            }
            try map.?.add_row(data[line_start..i]);
            line_start = i + 1;
        }
        i += 1;
    }

    // std.log.info("map {d}x{d}", .{ map.?.width, map.?.height });

    var res: u128 = 0;
    var res2: u128 = 0;
    for (0..map.?.height) |row| {
        for (0..map.?.width) |col| {
            const pos = Position.init(@intCast(col), @intCast(row));
            if (map.?.map.get(pos).? == 0) {
                const tops = try map.?.dfs(pos);
                res += tops;
                // std.log.info("Pos: {d},{d} reached {d}", .{ pos.x, pos.y, tops });
                const perm = try map.?.dfs_permutations(pos);
                res2 += perm;
            }
        }
    }

    // try map.?.print_map();

    return [2]u128{ res, res2 };
}
