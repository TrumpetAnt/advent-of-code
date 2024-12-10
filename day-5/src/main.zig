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

const TokenType = enum { comma, number, pipe, semicolon, newline, nil };

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
        if (self.data[self.cursor] == 10) {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.newline };
        }
        if (self.data[self.cursor] == 44) {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.comma };
        }
        if (self.data[self.cursor] == 59) {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.semicolon };
        }
        if (self.data[self.cursor] == 124) {
            self.cursor += 1;
            return .{ .token = self.data[self.cursor - 1 .. self.cursor], .token_type = TokenType.pipe };
        }
        var junk_cursor: usize = 0;
        while (self.cursor < self.data.len and self.data[self.cursor] != 0) {
            if (self.data[self.cursor] >= 48 and self.data[self.cursor] <= 57) {
                break;
            }
            if (self.data[self.cursor] == 10 or self.data[self.cursor] == 44 or self.data[self.cursor] == 59 or self.data[self.cursor] == 124) {
                break;
            }
            junk_cursor += 1;
            self.cursor += 1;
        }
        return .{ .token = self.data[self.cursor - junk_cursor .. self.cursor], .token_type = TokenType.nil };
    }
};

const file_path = "input.txt";
const file_size = 16000; //15856;

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
    const res = work_part_one(&big_buf) catch {
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

fn work_part_one(data: []const u8) ![2]i64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var page_requirements = std.AutoHashMap(u32, []std.ArrayList(u32)).init(
        allocator,
    );

    var tokenizer = Tokenizer.init(data);
    var window: [3]Token = [3]Token{ Token.nil(), Token.nil(), Token.nil() };
    var i_rules: u8 = 0;
    while (true) {
        const token = tokenizer.next() catch {
            break;
        };
        if (token.token_type == TokenType.newline) {
            i_rules = 0;
            continue;
        }
        window[i_rules] = token;

        if (i_rules == 2) {
            const a = try window[0].parseInt(u32);
            const b = try window[2].parseInt(u32);
            if (!page_requirements.contains(b)) {
                var x = try allocator.alloc(std.ArrayList(u32), 1);
                x[0] = std.ArrayList(u32).init(allocator);
                defer x[0].deinit();
                try page_requirements.put(b, x);
            }
            if (page_requirements.get(b)) |requirements| {
                try requirements[0].append(a);
            }
        }
        i_rules += 1;
        if (token.token_type == TokenType.semicolon) {
            _ = try tokenizer.next();
            break;
        }
    }

    var stupid = std.ArrayList(u32).init(allocator);
    var summerino: u32 = 0;
    var summerino_dos: u32 = 0;
    var end = false;
    var i_update: u32 = 0;
    while (!end) {
        stupid.clearRetainingCapacity();
        while (true) {
            const token = tokenizer.next() catch {
                end = true;
                break;
            };

            switch (token.token_type) {
                TokenType.number => {
                    const v = try token.parseInt(u32);
                    try stupid.append(v);
                },
                TokenType.newline => break,
                else => {},
            }
        }

        var disqualified = try test_stupid(stupid.items, &page_requirements, allocator);
        // std.log.info("disqualified: {d}", .{disqualified});
        if (disqualified < 0 and stupid.items.len > 0) {
            summerino += stupid.items[stupid.items.len / 2];
        }
        if (disqualified >= 0) {
            // var a_disc = disqualified;
            var yabba = try stupid.clone();
            if (disqualified != try test_stupid(yabba.items, &page_requirements, allocator)) {
                std.log.info("que", .{});
            }
            var max_count: i32 = 10000;
            while (disqualified >= 0 and max_count > 0) {
                // std.log.info("pre swap {any}", .{yabba.items});
                if (disqualified > 0) {
                    const k: usize = @intCast(disqualified);
                    const tmp = yabba.items[k - 1];
                    yabba.items[k - 1] = yabba.items[k];
                    yabba.items[k] = tmp;
                } else {
                    std.log.err("whopsie daisy", .{});
                    break;
                }
                disqualified = try test_stupid(yabba.items, &page_requirements, allocator);
                // std.log.info("{d} tried {any}", .{ disqualified, yabba.items });
                max_count -= 1;
            }
            if (disqualified < 0 and yabba.items.len > 0) {
                summerino_dos += yabba.items[yabba.items.len / 2];
            }
        }
        // std.log.info("Stuff {d} {any}", .{ i_update, stupid.items });
        i_update += 1;
    }

    return [2]i64{ summerino, summerino_dos };
}

fn test_stupid(stupid: []u32, page_requirements: *std.AutoHashMap(u32, []std.ArrayList(u32)), allocator: std.mem.Allocator) !i32 {
    var disqualifying_pages = std.AutoHashMap(usize, bool).init(
        allocator,
    );
    for (0..stupid.len) |i| {
        const v = stupid[i];
        if (disqualifying_pages.get(v)) |disqualifying| {
            if (disqualifying) {
                const res: i32 = @intCast(i);
                if (res < 0) {
                    std.log.err("what the fuck {d}", .{res});
                }
                return res;
            }
        }
        if (page_requirements.get(v)) |requirements| {
            for (0..requirements[0].items.len) |j| {
                if (!disqualifying_pages.contains(requirements[0].items[j])) {
                    try disqualifying_pages.put(requirements[0].items[j], true);
                }
            }
        }
        try disqualifying_pages.put(v, false);
    }
    return -1;
}
