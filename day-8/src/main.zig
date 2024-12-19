const std = @import("std");

const Token = struct {
    token: []const u8,
    token_type: TokenType,

    fn nil() Token {
        return .{ .token = undefined, .token_type = TokenType.nil };
    }

    pub fn parseInt(self: Token, comptime T: type) !T {
        return try std.fmt.parseInt(T, self.token, 10);
    }
};

const TokenizerError = error{EmptyError};

const TokenType = enum { dot, newline, char, nil };

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
        if ((self.data[self.cursor] >= 48 and self.data[self.cursor] <= 57) or
            (self.data[self.cursor] >= 65 and self.data[self.cursor] <= 90) or
            (self.data[self.cursor] >= 97 and self.data[self.cursor] <= 122))
        {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.char };
        }
        if (self.data[self.cursor] == '\n') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.newline };
        }
        if (self.data[self.cursor] == '.') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.dot };
        }
        var junk_cursor: usize = 0;
        while (self.cursor < self.data.len and self.data[self.cursor] != 0) {
            if ((self.data[self.cursor] >= 48 and self.data[self.cursor] <= 57) or
                (self.data[self.cursor] >= 65 and self.data[self.cursor] <= 90) or
                (self.data[self.cursor] >= 97 and self.data[self.cursor] <= 122))
            {
                break;
            }
            if (self.data[self.cursor] == '\n' or
                self.data[self.cursor] == '.')
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
const file_size = 26000; //15856;

const Position = struct {
    x: i32,
    y: i32,
    fn init(x: i32, y: i32) Position {
        return .{ .x = x, .y = y };
    }
};

const RectMap = struct {
    allocator: std.mem.Allocator,
    map: *std.AutoHashMap(Position, Token),
    type_to_list: *std.AutoHashMap(u8, *std.ArrayList(Position)),
    antinodes: *std.AutoHashMap(Position, bool),
    antinodes_p2: *std.AutoHashMap(Position, bool),
    width: usize,
    height: usize,

    fn init(allocator: std.mem.Allocator, width: usize) !RectMap {
        const map = try allocator.create(std.AutoHashMap(Position, Token));
        const type_to_list = try allocator.create(std.AutoHashMap(u8, *std.ArrayList(Position)));
        const antinodes = try allocator.create(std.AutoHashMap(Position, bool));
        const antinodes_p2 = try allocator.create(std.AutoHashMap(Position, bool));

        map.* = std.AutoHashMap(Position, Token).init(allocator);
        type_to_list.* = std.AutoHashMap(u8, *std.ArrayList(Position)).init(allocator);
        antinodes.* = std.AutoHashMap(Position, bool).init(allocator);
        antinodes_p2.* = std.AutoHashMap(Position, bool).init(allocator);

        return .{ .allocator = allocator, .map = map, .type_to_list = type_to_list, .antinodes = antinodes, .antinodes_p2 = antinodes_p2, .width = width, .height = 0 };
    }

    fn add_row(self: *RectMap, row: []Token) !void {
        for (0..row.len) |x| {
            if (row[x].token_type != TokenType.char) {
                continue;
            }
            const position = Position.init(@intCast(x), @intCast(self.height));
            try self.map.put(position, row[x]);
            if (!self.type_to_list.contains(row[x].token[0])) {
                const list = try self.allocator.create(std.ArrayList(Position));
                list.* = std.ArrayList(Position).init(self.allocator);
                try self.type_to_list.put(row[x].token[0], list);
            }
            if (self.type_to_list.get(row[x].token[0])) |list| {
                try list.append(position);
            }
        }
        self.height += 1;
    }

    fn calculate_antinodes(self: *RectMap) !usize {
        var type_iter = self.type_to_list.iterator();
        while (true) {
            const next = type_iter.next();
            if (next == null) {
                break;
            }
            // const key = next.?.key_ptr.*;
            const val = next.?.value_ptr.*;
            // std.log.info("type_to_list[{c}]: {any}", .{ key, val.items });
            for (0..val.items.len) |i| {
                for (0..val.items.len) |j| {
                    if (i == j) {
                        continue;
                    }
                    const antinode_1 = self.check_antinode(val.items[i], val.items[j]);
                    if (antinode_1 != null) {
                        try self.antinodes.put(antinode_1.?, true);
                    }

                    var depth: i32 = 0;
                    var an_p2 = self.check_antinode_p2(val.items[i], val.items[j], depth);
                    while (an_p2 != null) {
                        try self.antinodes_p2.put(an_p2.?, true);
                        depth += 1;
                        an_p2 = self.check_antinode_p2(val.items[i], val.items[j], depth);
                    }
                }
            }
        }
        return @intCast(self.antinodes.count());
    }

    fn check_antinode(self: *RectMap, a: Position, b: Position) ?Position {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const px = a.x + dx;
        const py = a.y + dy;
        // std.log.info("checking ({d},{d}) against map size {d}x{d}", .{ px, py, self.width, self.height });
        if (px >= 0 and px < self.width and py >= 0 and py < self.height) {
            return Position.init(px, py);
        }
        return null;
    }

    fn check_antinode_p2(self: *RectMap, a: Position, b: Position, dist: i32) ?Position {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const px = a.x + dx * dist;
        const py = a.y + dy * dist;
        // std.log.info("checking ({d},{d}) against map size {d}x{d}", .{ px, py, self.width, self.height });
        if (px >= 0 and px < self.width and py >= 0 and py < self.height) {
            return Position.init(px, py);
        }
        return null;
    }

    fn print_map(self: *RectMap) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.writeByte('\n');
        for (0..self.height) |row| {
            for (0..self.width) |col| {
                const pos = Position.init(@intCast(col), @intCast(row));
                if (self.antinodes_p2.contains(pos)) {
                    try stdout.writeByte('#');
                    continue;
                }
                if (self.map.get(pos)) |token| {
                    try stdout.writeByte(token.token[0]);
                    continue;
                }
                try stdout.writeByte('.');
            }
            try stdout.writeByte('\n');
        }
        try stdout.writeByte('\n');
        try stdout.print("no antinodes: {d}\n", .{self.antinodes.count()});
    }
};

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
    const res = work(&big_buf) catch |err| {
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

    var tokenizer = Tokenizer.init(data);
    const token_list = try allocator.create(std.ArrayList(Token));
    token_list.* = std.ArrayList(Token).init(allocator);
    var map: ?RectMap = null;

    while (true) {
        const token = tokenizer.next() catch {
            try map.?.add_row(token_list.items);
            break;
        };
        if (token.token_type == TokenType.newline) {
            if (map == null) {
                map = try RectMap.init(allocator, token_list.items.len);
            }
            try map.?.add_row(token_list.items);
            token_list.clearRetainingCapacity();
            continue;
        }
        try token_list.append(token);
    }

    const no_antinodes = try map.?.calculate_antinodes();

    // try map.?.print_map();

    return [2]u128{ @intCast(no_antinodes), @intCast(map.?.antinodes_p2.count()) };
}
