const std = @import("std");

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
    const end = std.mem.indexOf(u8, &big_buf, "\x00").?;
    const post_load = o;
    const res = work(big_buf[0..end]) catch |err| {
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

const Block = struct {
    id: u32,
    size: u8,
    gap: u8,

    fn init(id: u32, size: u8, gap: u8) Block {
        return .{
            .id = id,
            .size = size,
            .gap = gap,
        };
    }
};

fn work(data: []const u8) ![2]u128 {
    std.log.info("data: {s} len {d}", .{ data, data.len });

    // read blocks
    // loop
    //   find next gap,
    //   fill with last elem,
    //   update block list,
    // end loop if no next gap

    var checksum: u64 = 0;
    var checksum_cursor: usize = 0;
    var front_cursor: usize = 0;
    var back_cursor: usize = 0;
    var back_num_stored: usize = 0;
    var back_num_quantity: u8 = 0;

    const stdout = std.io.getStdOut().writer();
    try stdout.writeByte('\n');

    while (front_cursor + back_cursor < data.len) {
        var num: u8 = data[front_cursor] - 48;
        const is_padding = front_cursor % 2 == 1;
        const id: usize = @divFloor(front_cursor, 2);
        // std.log.info("num: {d} is_padding: {any} id: {d}", .{ num, is_padding, id });
        front_cursor += 1;
        if (!is_padding) {
            for (0..num) |_| {
                checksum += checksum_cursor * id;
                checksum_cursor += 1;
                // std.log.info("checksum: {d} cursor: {d} id: {d}", .{ checksum, checksum_cursor, id });
                try stdout.print("({d})", .{id});
                try stdout.writeByte(' ');
            }
        } else {
            while (num > 0 and front_cursor + back_cursor < data.len) {
                if (back_num_quantity == 0) {
                    back_num_quantity = data[data.len - back_cursor - 1] - 48;
                    back_num_stored = @divFloor(data.len - back_cursor - 1, 2);
                    // std.log.info("quant: {d} stored {d} cursor: {d}", .{ back_num_quantity, back_num_stored, back_cursor });
                    back_cursor += 2;
                }
                if (back_num_quantity <= num) {
                    for (0..back_num_quantity) |_| {
                        checksum += checksum_cursor * back_num_stored;
                        checksum_cursor += 1;
                        try stdout.print("[{d}]", .{back_num_stored});
                        try stdout.writeByte(' ');
                    }
                    num -= back_num_quantity;
                    back_num_quantity = 0;
                } else {
                    for (0..num) |_| {
                        checksum += checksum_cursor * back_num_stored;
                        checksum_cursor += 1;
                        try stdout.print("{d}", .{back_num_stored});
                        try stdout.writeByte(' ');
                    }
                    back_num_quantity -= num;
                    num = 0;
                }
            }
        }
    }
    for (0..back_num_quantity) |_| {
        checksum += checksum_cursor * back_num_stored;
        checksum_cursor += 1;
        try stdout.print("[{d}]", .{back_num_stored});
        try stdout.writeByte(' ');
    }
    try stdout.writeByte('\n');
    return [2]u128{ checksum, 0 };
}
