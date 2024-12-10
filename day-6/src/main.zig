const std = @import("std");

const Token = struct {
    token: []const u8,
    token_type: TokenType,

    fn nil() Token {
        return .{ .token = undefined, .token_type = TokenType.nil };
    }
};

const TokenizerError = error{EmptyError};

const TokenType = enum { obstacle, open, guard, newline, nil };

const Tokenizer = struct {
    data: []const u8,
    cursor: usize,

    fn init(data: []const u8) Tokenizer {
        return .{ .data = data, .cursor = 0 };
    }

    fn next(self: *Tokenizer) TokenizerError!Token {
        if (self.cursor >= self.data.len or self.data[self.cursor] == 0) {
            return TokenizerError.EmptyError;
        }
        if (self.data[self.cursor] == '\n') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.newline };
        }
        if (self.data[self.cursor] == '#') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.obstacle };
        }
        if (self.data[self.cursor] == '.') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.open };
        }
        if (self.data[self.cursor] == '^') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.guard };
        }
        var junk_cursor: usize = 0;
        while (self.cursor < self.data.len and self.data[self.cursor] != 0) {
            if (self.data[self.cursor] == '\n' or
                self.data[self.cursor] == '#' or
                self.data[self.cursor] == '.' or
                self.data[self.cursor] == '^')
            {
                break;
            }
            junk_cursor += 1;
            self.cursor += 1;
        }
        return .{ .token = self.data[self.cursor - junk_cursor .. self.cursor], .token_type = TokenType.nil };
    }
};

const file_path = "input.txt";
const file_size = 18000; //15856;

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
    const post_load = o;
    const res = work(&big_buf) catch {
        std.log.info("whops", .{});
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
    var b: [10]u8 = undefined;
    const s = try std.fmt.bufPrint(&b, "{d},{d}\n", .{ res[0], res[1] });
    const stdout = std.io.getStdOut().writer();
    _ = try stdout.write(s);
}

const Position = struct {
    x: u32,
    y: u32,
    fn init(x: u32, y: u32) Position {
        return .{ .x = x, .y = y };
    }
};

const GuardIterator = struct {
    map: *std.ArrayListAligned(std.ArrayList(Token), null),
    obstacles_by_row: *std.AutoHashMap(u32, *std.ArrayList(u32)),
    obstacles_by_col: *std.AutoHashMap(u32, *std.ArrayList(u32)),
    direction: u8,
    pos: Position,
    visited: std.AutoHashMap(i32, bool),
    finished: bool,

    fn init(map: *std.ArrayListAligned(std.ArrayList(Token), null), obstacles_by_row: *std.AutoHashMap(u32, *std.ArrayList(u32)), obstacles_by_col: *std.AutoHashMap(u32, *std.ArrayList(u32)), allocator: std.mem.Allocator) GuardIterator {
        return .{ .map = map, .direction = 0, .pos = Position.init(4, 6), .obstacles_by_row = obstacles_by_row, .obstacles_by_col = obstacles_by_col, .visited = std.AutoHashMap(i32, bool).init(allocator), .finished = false };
    }

    fn visitedCount(self: *GuardIterator) usize {
        var buf: [20000]u8 = std.mem.zeroes([20000]u8);
        var buf_cursor: usize = 0;
        for (0..self.map.items.len) |i| {
            const row = self.map.items[i];
            for (0..row.items.len) |j| {
                const casted: i32 = @intCast(row.items.len * i + j);
                const token: Token = row.items[j];
                buf[buf_cursor] = '.';

                if (self.visited.contains(casted)) {
                    buf[buf_cursor] = 'X';
                }
                if (token.token_type == TokenType.obstacle) {
                    buf[buf_cursor] = '#';
                }
                if (token.token_type == TokenType.guard) {
                    buf[buf_cursor] = '^';
                }
                buf_cursor += 1;
            }
            buf[buf_cursor] = '\n';
            buf_cursor += 1;
        }
        _ = std.io.getStdOut().write(&buf) catch {};
        // std.log.info("\n{s}", .{buf});

        var visited_iter = self.visited.iterator();
        while (true) {
            const a = visited_iter.next();
            if (a == null) {
                break;
            }
            if (!a.?.value_ptr.*) {
                std.log.info("value outside of thing-a-ma-bob ({d})", .{a.?.key_ptr.*});
            }
        }

        return self.visited.count();
    }

    fn next(self: *GuardIterator) ?Position {
        if (self.finished) {
            return null;
        }
        var any_obstacle = false;
        var n: usize = 0;
        switch (self.direction) {
            0 => {
                n = 0;
            },
            1 => {
                n = self.map.items[0].items.len;
            },
            2 => {
                n = self.map.items.len;
            },
            3 => {
                n = 0;
            },
            else => {},
        }
        var obstacles: *std.ArrayList(u32) = undefined;
        if (self.direction % 2 == 0) {
            if (self.obstacles_by_col.get(self.pos.x)) |obs| {
                obstacles = obs;
                // std.log.info("col {d}: {any}", .{ self.pos.x, obs.items });
            }
        } else {
            if (self.obstacles_by_row.get(self.pos.y)) |obs| {
                obstacles = obs;
                // std.log.info("row {d}: {any}", .{ self.pos.y, obs.items });
            }
        }
        for (0..obstacles.items.len) |i| {
            const obstacle = obstacles.items[i];
            switch (self.direction) {
                0 => {
                    if (obstacle < self.pos.y and obstacle >= n) {
                        n = obstacle;
                        any_obstacle = true;
                    }
                },
                1 => {
                    if (obstacle > self.pos.x and obstacle <= n) {
                        n = obstacle;
                        any_obstacle = true;
                    }
                },
                2 => {
                    if (obstacle > self.pos.y and obstacle <= n) {
                        n = obstacle;
                        any_obstacle = true;
                    }
                },
                3 => {
                    if (obstacle < self.pos.x and obstacle >= n) {
                        n = obstacle;
                        any_obstacle = true;
                    }
                },
                else => {},
            }
        }

        const prev_pos = self.pos;

        if (!any_obstacle) {
            self.finished = true;
            switch (self.direction) {
                0 => {
                    if (n == self.map.items.len) {
                        n = 0;
                    }
                    self.pos.y = @intCast(n);
                },
                1 => {
                    if (n == self.map.items[0].items.len) {
                        n -= 1;
                    }
                    self.pos.x = @intCast(n);
                },
                2 => {
                    if (n == 0) {
                        n = self.map.items.len - 1;
                    }
                    self.pos.y = @intCast(n);
                },
                3 => {
                    self.pos.x = @intCast(n);
                },
                else => {},
            }
        } else {
            switch (self.direction) {
                0 => {
                    self.pos.y = @intCast(n + 1);
                },
                1 => {
                    self.pos.x = @intCast(n - 1);
                },
                2 => {
                    self.pos.y = @intCast(n - 1);
                },
                3 => {
                    self.pos.x = @intCast(n + 1);
                },
                else => {},
            }
        }
        const a: i32 = @intCast(self.pos.x);
        const b: i32 = @intCast(prev_pos.x);
        const c: i32 = @intCast(self.pos.y);
        const d: i32 = @intCast(prev_pos.y);
        const in_the_a: i32 = @intCast(self.map.items[0].items.len);
        const diff_x: i32 = b - a;
        const diff_x_abs: i32 = @intCast(@abs(diff_x));
        var sign_diff_x: i32 = 1;
        if (diff_x < 0) {
            sign_diff_x = -1;
        }
        const diff_y: i32 = d - c;
        const diff_y_abs: i32 = @intCast(@abs(diff_y));
        var sign_diff_y: i32 = 1;
        if (diff_y < 0) {
            sign_diff_y = -1;
        }
        const total_tiles = self.map.items.len * self.map.items[0].items.len;
        std.log.info("Total tiles: {d}", .{total_tiles});
        for (0..@abs(diff_x_abs)) |x| {
            const casted: i32 = @intCast(x);
            const _i = (a + sign_diff_x * casted) + c * in_the_a;
            if (!self.visited.contains(_i)) {
                self.visited.put(_i, _i < total_tiles) catch {
                    return null;
                };
            }
        }
        for (0..@abs(diff_y_abs)) |y| {
            const casted: i32 = @intCast(y);
            const _i = a + (c + casted * sign_diff_y) * in_the_a;
            if (!self.visited.contains(_i)) {
                self.visited.put(_i, _i < total_tiles) catch {
                    return null;
                };
            }
        }
        self.direction = (self.direction + 1) % 4;
        return self.pos;
    }
};

fn work(data: []const u8) ![2]i64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tokenizer = Tokenizer.init(data);
    var end = false;
    var map: std.ArrayListAligned(std.ArrayList(Token), null) = std.ArrayList(std.ArrayList(Token)).init(allocator);
    var row_vec: std.ArrayList(Token) = undefined;

    var obstacles_by_row = std.AutoHashMap(u32, *std.ArrayList(u32)).init(
        allocator,
    );
    var obstacles_by_col = std.AutoHashMap(u32, *std.ArrayList(u32)).init(
        allocator,
    );
    var init_pos: Position = undefined;
    var row_count: u32 = 0;

    while (!end) {
        row_vec = std.ArrayList(Token).init(allocator);
        while (true) {
            const token = tokenizer.next() catch {
                end = true;
                break;
            };
            switch (token.token_type) {
                TokenType.newline => {
                    try map.append(try row_vec.clone());
                    row_vec.clearRetainingCapacity();
                    row_count += 1;
                },
                TokenType.obstacle => {
                    const row: u32 = @intCast(map.items.len);
                    const col: u32 = @intCast(row_vec.items.len);
                    if (!obstacles_by_row.contains(row)) {
                        const list = try allocator.create(std.ArrayList(u32));
                        list.* = std.ArrayList(u32).init(allocator);
                        try obstacles_by_row.put(row, list);
                    }
                    if (obstacles_by_row.get(row)) |arr| {
                        try arr.*.append(col);
                    }
                    if (!obstacles_by_col.contains(col)) {
                        const list = try allocator.create(std.ArrayList(u32));
                        list.* = std.ArrayList(u32).init(allocator);
                        try obstacles_by_col.put(col, list);
                    }
                    if (obstacles_by_col.get(col)) |arr| {
                        try arr.*.append(row);
                    }
                    try row_vec.append(token);
                },
                TokenType.guard => {
                    init_pos = Position.init(@intCast(row_vec.items.len), row_count);
                    try row_vec.append(token);
                },
                else => {
                    try row_vec.append(token);
                },
            }
        }
    }

    var guard_iter = GuardIterator.init(&map, &obstacles_by_row, &obstacles_by_col, allocator);
    guard_iter.pos = init_pos;
    var prev = init_pos;
    while (true) {
        const next_pos = guard_iter.next();
        if (next_pos == null) {
            break;
        }
        std.log.info("Path ({d},{d})->({d},{d})", .{ prev.x, prev.y, next_pos.?.x, next_pos.?.y });
        prev = next_pos.?;
    }
    const res_one: i64 = @intCast(guard_iter.visitedCount());
    return [2]i64{ res_one, 0 };
}
