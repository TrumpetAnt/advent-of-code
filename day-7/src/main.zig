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

const TokenType = enum { space, number, colon, newline, nil };

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
        if (self.data[self.cursor] >= 48 and self.data[self.cursor] <= 57) {
            var len: usize = 1;
            while (self.cursor + len < self.data.len and self.data[self.cursor + len] >= 48 and self.data[self.cursor + len] <= 57) {
                len += 1;
            }
            self.cursor += len;
            return .{ .token = self.data[self.cursor - len .. self.cursor], .token_type = TokenType.number };
        }
        if (self.data[self.cursor] == '\n') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.newline };
        }
        if (self.data[self.cursor] == ' ') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.space };
        }
        if (self.data[self.cursor] == ':') {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.colon };
        }
        var junk_cursor: usize = 0;
        while (self.cursor < self.data.len and self.data[self.cursor] != 0) {
            if (self.data[self.cursor] >= 48 and self.data[self.cursor] <= 57) {
                break;
            }
            if (self.data[self.cursor] == '\n' or
                self.data[self.cursor] == ' ' or
                self.data[self.cursor] == ':')
            {
                break;
            }
            junk_cursor += 1;
            self.cursor += 1;
        }
        return .{ .token = self.data[self.cursor - junk_cursor .. self.cursor], .token_type = TokenType.nil };
    }
};

const Operator = enum { mul, add };

const Equation = struct {
    target: u128,
    numbers: *std.ArrayList(u128),

    fn init(tokens: []Token, allocator: std.mem.Allocator) !Equation {
        const list = try allocator.create(std.ArrayList(u128));
        list.* = std.ArrayList(u128).init(allocator);
        var target: u128 = 0;
        if (tokens.len > 0) {
            target = try tokens[0].parseInt(u128);
            var i: usize = 1;
            while (i < tokens.len) {
                if (tokens[i].token_type == TokenType.number) {
                    try list.append(try tokens[i].parseInt(u128));
                }
                i += 1;
            }
        }

        return .{ .target = target, .numbers = list };
    }

    fn attempt_solve(self: *Equation) !bool {
        const wha: usize = 1;
        const n: usize = wha << @intCast(self.numbers.items.len - wha);
        std.log.info("Solve attempt: {d}={any} [{d}]", .{ self.target, self.numbers.items, n });
        for (0..n) |i| {
            if (self.target == try thinga_binga(self.numbers.items, i)) {
                std.log.info("Equation checks out: {d}={any}", .{ self.target, self.numbers.items });
                return true;
            }
        }
        return false;
    }
};

fn thinga_binga(vals: []u128, iter: usize) !u128 {
    var total: u128 = vals[0];
    for (1..vals.len) |i| {
        const op = iter_to_operator(iter, i - 1);
        switch (op) {
            Operator.add => {
                total += vals[i];
            },
            Operator.mul => {
                total *= vals[i];
            },
        }
    }
    return total;
}

fn iter_to_operator(iter: usize, i: usize) Operator {
    const first_bit_zero = (iter >> @intCast(i)) % 2 == 0;
    if (first_bit_zero) {
        return Operator.mul;
    }
    return Operator.add;
}

const file_path = "input.txt";
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
    const equations = try allocator.create(std.ArrayList(*Equation));
    equations.* = std.ArrayList(*Equation).init(allocator);

    while (true) {
        const token = tokenizer.next() catch {
            const equation = try allocator.create(Equation);
            equation.* = try Equation.init(token_list.items, allocator);
            try equations.append(equation);
            break;
        };
        if (token.token_type == TokenType.newline) {
            const equation = try allocator.create(Equation);
            equation.* = try Equation.init(token_list.items, allocator);
            try equations.append(equation);
            token_list.clearRetainingCapacity();
            continue;
        }
        try token_list.append(token);
    }

    var total: u128 = 0;
    for (0..equations.items.len) |i| {
        if (try equations.items[i].attempt_solve()) {
            total += equations.items[i].target;
        }
    }

    return [2]u128{ total, 0 };
}
