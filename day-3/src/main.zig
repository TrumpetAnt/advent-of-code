const std = @import("std");
const zbench = @import("zbench");

const Token = struct {
    token: []const u8,
    token_type: TokenType,

    fn junk() Token {
        return .{ .token = undefined, .token_type = TokenType.junk };
    }
};

const TokenizerError = error{EmptyError};

const TokenType = enum { mul, left_par, right_par, comma, number, do, dont, junk };

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
        if (self.check_mul_token()) |token| {
            self.cursor += token.token.len;
            return token;
        }
        if (self.check_do_token()) |token| {
            self.cursor += token.token.len;
            return token;
        }
        if (self.check_dont_token()) |token| {
            self.cursor += token.token.len;
            return token;
        }
        if (self.data[self.cursor] >= 48 and self.data[self.cursor] <= 57) {
            var len: usize = 1;
            while (self.data[self.cursor + len] >= 48 and self.data[self.cursor + len] <= 57) {
                len += 1;
            }
            self.cursor += len;
            return .{ .token = self.data[self.cursor - len .. self.cursor], .token_type = TokenType.number };
        }
        if (self.data[self.cursor] == 40) {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.left_par };
        }
        if (self.data[self.cursor] == 41) {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.right_par };
        }
        if (self.data[self.cursor] == 44) {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.comma };
        }
        var junk_cursor: usize = 0;
        while (self.cursor < self.data.len and self.data[self.cursor] != 0) {
            if (self.check_mul_token()) |_| {
                break;
            }
            if (self.check_do_token()) |_| {
                break;
            }
            if (self.check_dont_token()) |_| {
                break;
            }
            if (self.data[self.cursor] >= 48 and self.data[self.cursor] <= 57) {
                break;
            }
            if (self.data[self.cursor] == 40 or self.data[self.cursor] == 41 or self.data[self.cursor] == 44) {
                break;
            }
            junk_cursor += 1;
            self.cursor += 1;
        }
        return .{ .token = self.data[self.cursor - junk_cursor .. self.cursor], .token_type = TokenType.junk };
    }

    fn check_mul_token(self: *Tokenizer) ?Token {
        const word = "mul";
        if (self.cursor + word.len <= self.data.len and std.mem.eql(u8, self.data[self.cursor .. self.cursor + word.len], word)) {
            return .{ .token = word, .token_type = TokenType.mul };
        }
        return null;
    }

    fn check_do_token(self: *Tokenizer) ?Token {
        const word = "do()";
        if (self.cursor + word.len <= self.data.len and std.mem.eql(u8, self.data[self.cursor .. self.cursor + word.len], word)) {
            return .{ .token = word, .token_type = TokenType.do };
        }
        return null;
    }

    fn check_dont_token(self: *Tokenizer) ?Token {
        const word = "don't()";
        if (self.cursor + word.len <= self.data.len and std.mem.eql(u8, self.data[self.cursor .. self.cursor + word.len], word)) {
            return .{ .token = word, .token_type = TokenType.dont };
        }
        return null;
    }
};

const file_path = "input.txt";

const TokenizerBenchmark = struct {
    data: [19218]u8,

    fn init() TokenizerBenchmark {
        const f = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            std.log.info("hmm: {}", .{err});
            return .{ .data = undefined };
        };
        defer f.close();

        var buf_reader = std.io.bufferedReader(f.reader());
        const in_stream = buf_reader.reader();
        var big_buf = std.mem.zeroes([19218]u8);
        _ = in_stream.readAll(&big_buf) catch {};
        return .{ .data = big_buf };
    }

    pub fn run(self: TokenizerBenchmark, _: std.mem.Allocator) void {
        const res = work_tokenizer(&(self.data)) catch |err| {
            std.log.err("we shat the bed in another way: {}", .{err});
            return;
        };
        if (std.mem.eql(u8, file_path, "demo.txt") and (res[0] != 161 or res[1] != 48)) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
        // 63869500
        // 174561379
        if (std.mem.eql(u8, file_path, "input.txt") and (res[0] != 174561379 or res[1] != 106921067)) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
        //  2113135-19097157
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.addParam("Array", &TokenizerBenchmark.init(), .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}

fn work_tokenizer(data: []const u8) ![2]i64 {
    var tokenizer = Tokenizer.init(data);

    var total: i64 = 0;
    var total_enable_disable: i64 = 0;

    var window: [5]Token = [5]Token{ Token.junk(), Token.junk(), Token.junk(), Token.junk(), Token.junk() };
    var cursor: usize = 0;
    var enabled = true;
    while (true) {
        const token = tokenizer.next() catch {
            break;
        };
        // std.log.info("enabled({any}) token({any})", .{ enabled, token.token_type });
        switch (token.token_type) {
            TokenType.do => {
                enabled = true;
            },
            TokenType.dont => {
                enabled = false;
            },
            TokenType.right_par => {
                // std.log.info("{any}", .{window});
                if (calcualte_window(&window, cursor)) |v| {
                    total += v;
                    if (enabled) {
                        total_enable_disable += v;
                    }
                }
            },
            else => {},
        }

        window[cursor % 5] = token;
        cursor += 1;
    }

    return [2]i64{ total, total_enable_disable };
}

fn calcualte_window(window: []Token, start: usize) ?i64 {
    if (!(window[start % 5].token_type == TokenType.mul)) {
        return null;
    }
    if (!(window[(start + 1) % 5].token_type == TokenType.left_par)) {
        return null;
    }

    if (!(window[(start + 2) % 5].token_type == TokenType.number)) {
        return null;
    }
    const a = std.fmt.parseInt(i32, window[(start + 2) % 5].token, 10) catch {
        return null;
    };

    if (!(window[(start + 3) % 5].token_type == TokenType.comma)) {
        return null;
    }

    if (!(window[(start + 4) % 5].token_type == TokenType.number)) {
        return null;
    }
    const b = std.fmt.parseInt(i32, window[(start + 4) % 5].token, 10) catch {
        return null;
    };
    return a * b;
}
