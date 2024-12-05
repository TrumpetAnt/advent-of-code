const std = @import("std");
const zbench = @import("zbench");

const file_path = "input.txt";
const file_size = 19742;

const Benchmark = struct {
    data: []u8,

    fn init(buffer: []u8) Benchmark {
        return .{ .data = buffer };
    }

    pub fn run(self: Benchmark, _: std.mem.Allocator) void {
        const res = work_part_one(self.data) catch |err| {
            std.log.err("we shat the bed in another way: {}", .{err});
            return;
        };
        if (std.mem.eql(u8, file_path, "demo.txt") and (res[0] != 18 or res[1] != 9)) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
        if (std.mem.eql(u8, file_path, "input.txt") and (res[0] != 2517 or res[1] != 1960)) {
            std.log.err("we shat the bed: {d}-{d}", .{ res[0], res[1] });
        }
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
    const res = work_part_one(&big_buf) catch {
        std.log.info("whops");
    };
    // std.log.info("whops {d} {d}", .{ res[0], res[1] });

    const stdout = std.io.getStdOut().writer();
    // var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    // defer bench.deinit();

    // try bench.addParam("WordSearch", &Benchmark.init(&big_buf), .{});

    // try stdout.writeAll("\n");
    // try bench.run(stdout);
    exit_code = std.os.linux.clock_gettime(std.os.linux.CLOCK.REALTIME, &o);
    if (exit_code != 0) {
        std.log.err("Failed syscall clock_gettime exit code {d}", .{exit_code});
        return;
    }
    const nano_diff = o.tv_nsec - start.tv_nsec + (o.tv_sec - start.tv_sec) * 1000000000;
    const nano_diff_load = o.tv_nsec - post_load.tv_nsec + (o.tv_sec - post_load.tv_sec) * 1000000000;
    std.log.info("Since start: {d}{d}.{d} μs", .{ @divTrunc(nano_diff, 1000000), @mod(@divTrunc(nano_diff, 1000), 1000), @mod(nano_diff, 1000) });
    std.log.info("Since load:  {d}{d}.{d} μs", .{ @divTrunc(nano_diff_load, 1000000), @mod(@divTrunc(nano_diff_load, 1000), 1000), @mod(nano_diff_load, 1000) });
    var b: [10]u8 = undefined;
    _ = try std.fmt.bufPrint(&b, "{d},{d}\n", .{ res[0], res[1] });
    _ = try stdout.write(&b);
}

const WorkErrors = error{ParsingError};

fn work_part_one(data: []const u8) ![2]i64 {
    // const lineLen = 11;
    const lineLen = 141;

    var xmax_count: i64 = 0;
    for (0..data.len) |i| {
        if (data[i] == '\n') {
            continue;
        }
        const col: usize = (i - 1) % lineLen;
        const row: usize = i / lineLen;
        if (col >= 3) {
            if (data[i] == 'X' and data[i - 1] == 'M' and data[i - 2] == 'A' and data[i - 3] == 'S') {
                xmax_count += 1;
            } else if (data[i] == 'S' and data[i - 1] == 'A' and data[i - 2] == 'M' and data[i - 3] == 'X') {
                xmax_count += 1;
            }
        }
        if (row >= 3) {
            if (data[i] == 'X' and data[i - lineLen] == 'M' and data[i - 2 * lineLen] == 'A' and data[i - 3 * lineLen] == 'S') {
                xmax_count += 1;
            } else if (data[i] == 'S' and data[i - lineLen] == 'A' and data[i - 2 * lineLen] == 'M' and data[i - 3 * lineLen] == 'X') {
                xmax_count += 1;
            }
        }
        if (col >= 3 and row >= 3) {
            if (data[i] == 'X' and data[i - lineLen - 1] == 'M' and data[i - 2 * lineLen - 2] == 'A' and data[i - 3 * lineLen - 3] == 'S') {
                xmax_count += 1;
            } else if (data[i] == 'S' and data[i - lineLen - 1] == 'A' and data[i - 2 * lineLen - 2] == 'M' and data[i - 3 * lineLen - 3] == 'X') {
                xmax_count += 1;
            }
        }
        if (col <= lineLen - 3 and row >= 3) {
            if (data[i] == 'X' and data[i - lineLen + 1] == 'M' and data[i - 2 * lineLen + 2] == 'A' and data[i - 3 * lineLen + 3] == 'S') {
                xmax_count += 1;
            } else if (data[i] == 'S' and data[i - lineLen + 1] == 'A' and data[i - 2 * lineLen + 2] == 'M' and data[i - 3 * lineLen + 3] == 'X') {
                xmax_count += 1;
            }
        }
    }

    var mas_count: i64 = 0;
    for (0..data.len) |i| {
        if (data[i] == '\n') {
            continue;
        }
        const col: usize = (i - 1) % lineLen;
        const row: usize = i / lineLen;

        if (col >= 2 and row >= 2) {
            if (data[i - lineLen - 1] == 'A') {
                const a = data[i - 2 * lineLen - 2];
                const b = data[i - 2 * lineLen];
                const c = data[i - 2];
                const d = data[i];
                if (((a == 'S' and d == 'M') or (a == 'M' and d == 'S')) and
                    ((b == 'S' and c == 'M') or (b == 'M' and c == 'S')))
                {
                    mas_count += 1;
                }
            }
        }
    }

    return [2]i64{ xmax_count, mas_count };
}
