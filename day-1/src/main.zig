const std = @import("std");
const zbench = @import("zbench");

const MyBenchmark = struct {
    data: []u8,

    fn init(data: []u8) MyBenchmark {
        // var buf_reader = std.io.bufferedReader(file.reader());
        // const in_stream = buf_reader.reader();

        return .{ .data = data };
    }

    pub fn run(self: MyBenchmark, _: std.mem.Allocator) void {
        var x = std.io.fixedBufferStream(self.data);
        const res = work_aux(x.reader()) catch |err| {
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

    const f = std.fs.cwd().openFile("input.txt", .{}) catch |err| {
        std.log.info("hmm: {}", .{err});
        return err;
    };
    defer f.close();
    var buf_reader = std.io.bufferedReader(f.reader());
    const in_stream = buf_reader.reader();
    var buffer: [13999]u8 = std.mem.zeroes([13999]u8);
    _ = try in_stream.readAll(&buffer);

    std.log.info("{s}", .{&buffer});
    try bench.addParam("Okay", &MyBenchmark.init(&buffer), .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}

fn work(_: std.mem.Allocator) void {
    _ = work_aux() catch |err| {
        std.log.err("{}", .{err});
        return;
    };
    // std.log.info("{d}-{d}", .{ res[0], res[1] });
}

fn work_aux(in_stream: anytype) ![2]i64 {
    var buffer: [1024]u8 = undefined;
    const num_rows = 1000;
    var col_1: [num_rows]i32 = undefined;
    var col_2: [num_rows]i32 = undefined;

    var i: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        col_1[i] = try std.fmt.parseInt(i32, line[0..5], 10);
        col_2[i] = try std.fmt.parseInt(i32, line[8..], 10);
        i += 1;
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
