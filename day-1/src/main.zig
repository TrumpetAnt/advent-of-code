const std = @import("std");
const zbench = @import("zbench");

const MyBenchmark = struct {
    data: [13999]u8,

    fn init() MyBenchmark {
        const f = std.fs.cwd().openFile("input.txt", .{}) catch |err| {
            std.log.info("hmm: {}", .{err});
            return .{ .data = undefined };
        };
        defer f.close();

        var buf_reader = std.io.bufferedReader(f.reader());
        const in_stream = buf_reader.reader();
        var big_buf = std.mem.zeroes([13999]u8);
        _ = in_stream.readAll(&big_buf) catch {};
        return .{ .data = big_buf };
    }

    pub fn run(self: MyBenchmark, _: std.mem.Allocator) void {
        const res = work(&(self.data)) catch |err| {
            std.log.err("we shat the bed in another way: {}", .{err});
            return;
        };
        if (res[0] != 2113135 or res[1] != 19097157) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
        //  2113135-19097157
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.addParam("Okay", &MyBenchmark.init(), .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}

fn work(buf: []const u8) ![2]i64 {
    var buffer: [1024]u8 = undefined;
    const num_rows = 1000;
    var col_1: [num_rows]i32 = undefined;
    var col_2: [num_rows]i32 = undefined;

    var i: u32 = 0;
    var buf_cursor: u32 = 0;
    var copy_cursor: u32 = 0;
    while (buf_cursor < buf.len and i < num_rows) {
        copy_cursor = 0;
        while (buf_cursor + copy_cursor < buf.len and buf[buf_cursor + copy_cursor] != '\n') {
            buffer[copy_cursor] = buf[buf_cursor + copy_cursor];
            copy_cursor += 1;
        }
        col_1[i] = try std.fmt.parseInt(i32, buffer[0..5], 10);
        col_2[i] = try std.fmt.parseInt(i32, buffer[8..13], 10);
        i += 1;
        buf_cursor += copy_cursor + 1;
    }

    std.mem.sort(i32, &col_1, {}, comptime std.sort.asc(i32));
    std.mem.sort(i32, &col_2, {}, comptime std.sort.asc(i32));

    var diff: u32 = 0;
    for (0..num_rows) |j| {
        diff += @abs(col_2[j] - col_1[j]);
    }

    var similarity: i64 = 0;
    var j_1: u32 = 0;
    var j_2: u32 = 0;
    while (j_1 < num_rows) {
        const val: i64 = col_1[j_1];
        var cursor_1: u32 = 0;
        while (j_1 + cursor_1 < num_rows and col_1[j_1 + cursor_1] == val) {
            cursor_1 += 1;
        }
        while (j_2 < num_rows and col_2[j_2] < val) {
            j_2 += 1;
        }
        var cursor_2: u32 = 0;
        while (j_2 + cursor_2 < num_rows and col_2[j_2 + cursor_2] == val) {
            cursor_2 += 1;
        }
        similarity += val * @as(i64, cursor_1) * @as(i64, cursor_2);
        j_1 += cursor_1;
        j_2 += cursor_2;
    }

    return [2]i64{ diff, similarity };
}