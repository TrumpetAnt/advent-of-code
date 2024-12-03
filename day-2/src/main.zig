const std = @import("std");
const zbench = @import("zbench");

const file_path = "input.txt";

const ArrayBenchmark = struct {
    data: [19062]u8,

    fn init() ArrayBenchmark {
        const f = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            std.log.info("hmm: {}", .{err});
            return .{ .data = undefined };
        };
        defer f.close();

        var buf_reader = std.io.bufferedReader(f.reader());
        const in_stream = buf_reader.reader();
        var big_buf = std.mem.zeroes([19062]u8);
        _ = in_stream.readAll(&big_buf) catch {};
        return .{ .data = big_buf };
    }

    pub fn run(self: ArrayBenchmark, _: std.mem.Allocator) void {
        const res = work(&(self.data)) catch |err| {
            std.log.err("we shat the bed in another way: {}", .{err});
            return;
        };
        if (std.mem.eql(u8, file_path, "demo.txt") and (res[0] != 3 or res[1] != 5)) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
        if (std.mem.eql(u8, file_path, "input.txt") and (res[0] != 639 or res[1] != 674)) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
        //  2113135-19097157
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.addParam("Array", &ArrayBenchmark.init(), .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}

fn work(buf: []const u8) ![2]i64 {
    var safe_count: i64 = 0;
    var safe_count_with_margin: i64 = 0;
    var cursor: u32 = 0;

    while (cursor < buf.len and buf[cursor] != 0) {
        var levels: [10]u8 = std.mem.zeroes([10]u8);
        var i: u8 = 0;
        while (cursor < buf.len and buf[cursor] != '\n' and buf[cursor] != 0) {
            var c: u32 = 0;
            while (cursor + c < buf.len and buf[cursor + c] >= 48 and buf[cursor + c] <= 57) {
                c += 1;
            }
            levels[i] = std.fmt.parseInt(u8, buf[cursor .. cursor + c], 10) catch |err| {
                std.log.info("Or here", .{});
                return err;
            };
            i += 1;
            cursor += c;
            while (cursor < buf.len and buf[cursor] == ' ') {
                cursor += 1;
            }
        }
        cursor += 1; // skip newline

        var safe = testReport(&levels, 255);
        if (safe) {
            safe_count += 1;
            safe_count_with_margin += 1;
        } else {
            for (0..10) |skip| {
                safe = testReport(&levels, skip);
                if (safe) {
                    break;
                }
            }
            if (safe) {
                safe_count_with_margin += 1;
            }
        }
        // if (safe) {
        //     std.log.info("Report safe: {any}", .{&levels});
        // } else {
        //     std.log.info("Report unsafe: {any}", .{&levels});
        // }
    }

    return [2]i64{ safe_count, safe_count_with_margin };
}

fn testReport(levels: []u8, skip: usize) bool {
    var loop_from: usize = 1;
    if (skip == 0 or skip == 1) {
        loop_from = 2;
    }
    var prev: u8 = levels[0];
    if (skip == 0) {
        prev = levels[1];
    }
    var prev_diff: i32 = 0;
    var safe = true;
    for (loop_from..levels.len) |level| {
        if (level == skip) {
            continue;
        }
        if (levels[level] == 0) {
            break;
        }
        const diff: i32 = @as(i32, levels[level]) - @as(i32, prev);
        safe = safe and diff != 0 and @abs(diff) < 4 and diff * prev_diff >= 0;
        if (!safe) {
            break;
        }
        prev_diff = diff;
        prev = levels[level];
    }
    return safe;
}
