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

fn work(data: []const u8) ![2]u128 {
    return [2]u128{ part_one(data), try part_two(data) };
}

fn part_one(data: []const u8) u128 {
    var checksum: u128 = 0;
    var checksum_cursor: usize = 0;
    var front_cursor: usize = 0;
    var back_cursor: usize = 0;
    var back_num_stored: usize = 0;
    var back_num_quantity: u8 = 0;

    while (front_cursor + back_cursor < data.len) {
        var num: u8 = data[front_cursor] - 48;
        const is_free_space = front_cursor % 2 == 1;
        const id: usize = @divFloor(front_cursor, 2);
        front_cursor += 1;
        if (!is_free_space) {
            for (0..num) |_| {
                checksum += checksum_cursor * id;
                checksum_cursor += 1;
            }
        } else {
            while (num > 0 and front_cursor + back_cursor < data.len) {
                if (back_num_quantity == 0) {
                    back_num_quantity = data[data.len - back_cursor - 1] - 48;
                    back_num_stored = @divFloor(data.len - back_cursor - 1, 2);
                    back_cursor += 2;
                }
                if (back_num_quantity <= num) {
                    for (0..back_num_quantity) |_| {
                        checksum += checksum_cursor * back_num_stored;
                        checksum_cursor += 1;
                    }
                    num -= back_num_quantity;
                    back_num_quantity = 0;
                } else {
                    for (0..num) |_| {
                        checksum += checksum_cursor * back_num_stored;
                        checksum_cursor += 1;
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
    }
    return checksum;
}

const Block = struct {
    id: u64,
    size: u32,
    padding: u32,
    prev: ?*Block,
    next: ?*Block,

    fn init(id: u64, size: u8, padding: u8) Block {
        return .{ .id = id, .size = @intCast(size), .padding = @intCast(padding), .prev = null, .next = null };
    }

    fn connect_prev(self: *Block, other: ?*Block) void {
        if (self.prev != null) {
            self.prev.?.next = null;
        }
        self.prev = other;
        if (other != null) {
            other.?.next = self;
        }
    }

    fn move_to_block(self: *Block, other: *Block) void {
        if (self.prev != null) {
            self.prev.?.padding += self.size + self.padding;
            if (self.next != null) {
                self.prev.?.next = self.next;
                self.next.?.prev = self.prev;
            } else {
                self.prev.?.next = null;
            }
        }
        self.next = other.next;
        other.next = self;
        if (self.next != null) {
            self.next.?.prev = self;
        }
        self.prev = other;
        self.padding = other.padding - self.size;
        other.padding = 0;
    }

    fn find_available(self: *Block, mem_size: u32) ?*Block {
        if (self.prev != null) {
            if (self.prev.?.find_available(mem_size)) |better_option| {
                return better_option;
            }
        }
        if (self.padding >= mem_size) {
            return self;
        }
        return null;
    }

    fn find_available_no_recursion(self: *Block, mem_size: u32) ?*Block {
        var cursor: ?*Block = self.prev;
        var better_option: ?*Block = null;
        while (cursor != null) {
            if (cursor.?.padding >= mem_size) {
                better_option = cursor;
            }
            cursor = cursor.?.prev;
        }
        if (better_option != null) {
            return better_option;
        }
        if (self.padding >= mem_size) {
            return self;
        }
        return null;
    }

    fn checksum(self: *Block, i: u128, acc: u128) u128 {
        var r_acc = acc;
        var r_i = i;
        for (0..self.size) |_| {
            r_acc += r_i * @as(u128, self.id);
            r_i += 1;
        }
        if (self.next == null) {
            return r_acc;
        }
        return self.next.?.checksum(r_i + @as(u128, self.padding), r_acc);
    }

    fn checksum_no_recursion(self: *Block, i: u128, acc: u128) u128 {
        var cursor: ?*Block = self;
        var r_acc = acc;
        var r_i = i;
        while (cursor != null) {
            for (0..cursor.?.size) |_| {
                r_acc += r_i * @as(u128, cursor.?.id);
                r_i += 1;
            }
            cursor = cursor.?.next;
        }
        return r_acc;
    }

    fn print(self: *Block, file: std.fs.File) !void {
        const writer = file.writer();
        for (0..self.size) |_| {
            try writer.print("{d} ", .{self.id});
        }
        for (0..self.padding) |_| {
            try writer.writeByte('.');
            try writer.writeByte(' ');
        }
        if (self.next != null) {
            try self.next.?.print(file);
        }
    }
};

fn part_two(data: []const u8) !u128 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var memory_list = std.ArrayList(*Block).init(allocator);

    var id_counter: u64 = 0;
    var i: usize = 0;
    var prev: ?*Block = null;
    while (i < data.len) {
        const size = data[i] - 48;
        var padding: u8 = 0;
        if (i + 1 < data.len) {
            padding = data[i + 1] - 48;
        }
        const block = try allocator.create(Block);
        block.* = Block.init(id_counter, size, padding);
        block.connect_prev(prev);
        try memory_list.append(block);
        prev = block;
        i += 2;
        id_counter += 1;
    }

    var cursor: ?*Block = memory_list.items[memory_list.items.len - 1];

    while (cursor != null) {
        const block = cursor.?;
        cursor = block.prev;
        if (block.prev != null) {
            const target = block.prev.?.find_available_no_recursion(block.size);
            if (target != null) {
                block.move_to_block(target.?);
            }
        }
    }

    // try memory_list.items[0].print(std.io.getStdOut());
    return memory_list.items[0].checksum_no_recursion(0, 0);
}
