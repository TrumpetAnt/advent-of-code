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
        if (std.mem.eql(u8, file_path, "demo.txt") and res[0] != 3 or res[1] != 0) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
        if (std.mem.eql(u8, file_path, "input.txt") and res[0] != 639 or res[1] != 0) {
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
    var copy_cursor: u32 = 0;
    var safe = true;
    var c: u32 = 0;
    while (copy_cursor + c < buf.len and buf[copy_cursor + c] >= 48 and buf[copy_cursor + c] <= 57) {
        c += 1;
    }
    var prev: i32 = std.fmt.parseInt(i32, buf[copy_cursor .. copy_cursor + c], 10) catch |err| {
        std.log.info("Shit here", .{});
        return err;
    };
    var prev_prev = 0;
    copy_cursor += c;
    var prev_diff: i32 = 0;
    while (true) {
        while (copy_cursor < buf.len and buf[copy_cursor] == ' ') {
            copy_cursor += 1;
        }
        if (copy_cursor >= buf.len or buf[copy_cursor] == 0) {
            if (safe) {
                safe_count += 1;
            }
            break;
        }
        if (buf[copy_cursor] == '\n') {
            if (safe) {
                safe_count += 1;
            }
            copy_cursor += 1;
            if (copy_cursor >= buf.len) {
                break;
            }
            safe = true;
            c = 0;
            while (copy_cursor + c < buf.len and buf[copy_cursor + c] >= 48 and buf[copy_cursor + c] <= 57) {
                c += 1;
            }
            prev_prev = 0;
            prev = std.fmt.parseInt(i32, buf[copy_cursor .. copy_cursor + c], 10) catch |err| {
                std.log.info("Or here", .{});
                return err;
            };
            // std.log.info("Or here {d}", .{c});
            copy_cursor += c;
            prev_diff = 0;
            continue;
        }
        c = 0;
        while (copy_cursor + c < buf.len and buf[copy_cursor + c] >= 48 and buf[copy_cursor + c] <= 57) {
            c += 1;
        }
        const v: i32 = std.fmt.parseInt(i32, buf[copy_cursor .. copy_cursor + c], 10) catch |err| {
            std.log.info("Or even here buf[{d}]={c}", .{ copy_cursor, buf[copy_cursor] });
            return err;
        };
        copy_cursor += c;
        const diff: i32 = prev - v;
        // const prev_safe = safe;
        safe = safe and diff != 0 and @abs(diff) < 4 and prev_diff * diff >= 0;
        if (!safe) {}
        // std.log.info("prev({d}) v({d}) safe({}) prev_safe({}) prev_diff({d})", .{ prev, v, safe, prev_safe, prev_diff });
        prev_prev = prev;
        prev = v;
        prev_diff = diff;
    }

    return [2]i64{ safe_count, 0 };
}
