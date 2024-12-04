const std = @import("std");
const zbench = @import("zbench");

const file_path = "input.txt";
const file_size = 19740;

const Benchmark = struct {
    data: [file_size]u8,

    fn init() Benchmark {
        const f = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            std.log.info("hmm: {}", .{err});
            return .{ .data = undefined };
        };
        defer f.close();

        var buf_reader = std.io.bufferedReader(f.reader());
        const in_stream = buf_reader.reader();
        var big_buf = std.mem.zeroes([file_size]u8);
        _ = in_stream.readAll(&big_buf) catch {};
        return .{ .data = big_buf };
    }

    pub fn run(self: Benchmark, _: std.mem.Allocator) void {
        const res = work_part_one(&(self.data)) catch |err| {
            std.log.err("we shat the bed in another way: {}", .{err});
            return;
        };
        if (std.mem.eql(u8, file_path, "demo.txt") and (res[0] != 18 or res[1] != 0)) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
        if (std.mem.eql(u8, file_path, "input.txt") and (res[0] != 2517 or res[1] != 0)) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.addParam("WordSearch", &Benchmark.init(), .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}

const WorkErrors = error{ParsingError};

fn work_part_one(data: []const u8) ![2]i64 {
    const lineLen = 141; //std.mem.indexOf(u8, data, "\n") orelse return WorkErrors.ParsingError;

    var xmax_count: i64 = 0;
    for (0..data.len) |i| {
        if (data[i] == '\n') {
            continue;
        }
        const col: usize = (i - 1) % lineLen;
        const row: usize = i / lineLen;
        // std.log.info("({d},{d},{d})", .{ col, row, i });
        if (col >= 3) {
            if (data[i] == 'X' and data[i - 1] == 'M' and data[i - 2] == 'A' and data[i - 3] == 'S') {
                // std.log.info("left: {c} {c} {c} {c} [{d}, {d}, {d}]", .{ data[i], data[i - 1], data[i - 2], data[i - 3], col, row, i });
                xmax_count += 1;
            } else if (data[i] == 'S' and data[i - 1] == 'A' and data[i - 2] == 'M' and data[i - 3] == 'X') {
                // std.log.info("left: {c} {c} {c} {c}  [{d}, {d}, {d}]", .{ data[i], data[i - 1], data[i - 2], data[i - 3], col, row, i });
                xmax_count += 1;
            }
        }
        if (row >= 3) {
            if (data[i] == 'X' and data[i - lineLen] == 'M' and data[i - 2 * lineLen] == 'A' and data[i - 3 * lineLen] == 'S') {
                // std.log.info("up: {c} {c} {c} {c}  [{d}, {d}, {d}]", .{ data[i], data[i - lineLen], data[i - 2 * lineLen], data[i - 3 * lineLen], col, row, i });
                xmax_count += 1;
            } else if (data[i] == 'S' and data[i - lineLen] == 'A' and data[i - 2 * lineLen] == 'M' and data[i - 3 * lineLen] == 'X') {
                // std.log.info("up: {c} {c} {c} {c}  [{d}, {d}, {d}]", .{ data[i], data[i - lineLen], data[i - 2 * lineLen], data[i - 3 * lineLen], col, row, i });
                xmax_count += 1;
            }
        }
        if (col >= 3 and row >= 3) {
            if (data[i] == 'X' and data[i - lineLen - 1] == 'M' and data[i - 2 * lineLen - 2] == 'A' and data[i - 3 * lineLen - 3] == 'S') {
                // std.log.info("up-left: {c} {c} {c} {c}  [{d}, {d}, {d}]", .{ data[i], data[i - lineLen - 1], data[i - 2 * lineLen - 2], data[i - 3 * lineLen - 3], col, row, i });
                xmax_count += 1;
            } else if (data[i] == 'S' and data[i - lineLen - 1] == 'A' and data[i - 2 * lineLen - 2] == 'M' and data[i - 3 * lineLen - 3] == 'X') {
                // std.log.info("up-left: {c} {c} {c} {c}  [{d}, {d}, {d}]", .{ data[i], data[i - lineLen - 1], data[i - 2 * lineLen - 2], data[i - 3 * lineLen - 3], col, row, i });
                xmax_count += 1;
            }
        }
        if (col <= lineLen - 3 and row >= 3) {
            if (data[i] == 'X' and data[i - lineLen + 1] == 'M' and data[i - 2 * lineLen + 2] == 'A' and data[i - 3 * lineLen + 3] == 'S') {
                // std.log.info("up-right: {c} {c} {c} {c}  [{d}, {d}, {d}]", .{ data[i], data[i - lineLen + 1], data[i - 2 * lineLen + 2], data[i - 3 * lineLen + 3], col, row, i });
                xmax_count += 1;
            } else if (data[i] == 'S' and data[i - lineLen + 1] == 'A' and data[i - 2 * lineLen + 2] == 'M' and data[i - 3 * lineLen + 3] == 'X') {
                // std.log.info("up-right: {c} {c} {c} {c}  [{d}, {d}, {d}]", .{ data[i], data[i - lineLen + 1], data[i - 2 * lineLen + 2], data[i - 3 * lineLen + 3], col, row, i });
                xmax_count += 1;
            }
        }
    }

    return [2]i64{ xmax_count, 0 };
}
