const std = @import("std");

const Chain = struct {
    val: u128,
    left: ?*Chain,
    right: ?*Chain,
    duplicate: ?*Chain,
    child: ?*Chain,
    depth: usize,

    fn init(val: u128) Chain {
        return .{ .val = val, .left = null, .right = null, .duplicate = null, .child = null, .depth = 0 };
    }

    fn step(self: *Chain, allocator: std.mem.Allocator) !?*Chain {
        if (self.val == 0) {
            const chain_link = try allocator.create(Chain);
            chain_link.* = Chain.init(1);
            self.child = chain_link;
            return chain_link;
        } else {
            const digits: u7 = std.math.log10_int(self.val) + 1; // 1-9 == 0; 10-99 == 1; 100-999 == 2;
            if (digits % 2 == 0) {
                const half_digits: u7 = digits / 2;
                const split = try std.math.powi(u128, 10, @intCast(half_digits));
                const l = @divTrunc(self.val, split);
                self.left = try allocator.create(Chain);
                self.left.?.* = Chain.init(l);
                self.right = try allocator.create(Chain);
                const r = @mod(self.val, split);
                self.right.?.* = Chain.init(r);
                std.log.info("funkylicious: split({d}) l({d}) r({d}))", .{ split, l, r });
                return null;
            } else {
                self.child = try allocator.create(Chain);
                self.child.?.* = Chain.init(self.val * 2024);
                return self.child.?;
            }
        }
    }

    fn set_child(self: *Chain, child: *Chain) void {
        self.child = child;
    }

    fn get_depth(self: *Chain, level: usize) usize {
        std.log.info("Checking depth for val {d} at level {d}", .{ self.val, level });
        var res: usize = 1;
        if (level >= 76) {
            // return 1;
            res = 1;
        } else {
            if (self.child != null) {
                std.log.info("goin deeper by child", .{});
                // return self.child.?.get_depth(level + 1);
                res = self.child.?.get_depth(level + 1);
            } else if (self.duplicate != null) {
                std.log.info("goin deeper by duplicate", .{});
                // return self.duplicate.?.get_depth(level);
                res = self.duplicate.?.get_depth(level);
            } else if (self.left != null) {
                std.log.info("goin deeper by split", .{});
                // return self.left.?.get_depth(level + 1) + self.right.?.get_depth(level + 1);
                res = self.left.?.get_depth(level + 1) + self.right.?.get_depth(level + 1);
            }
        }
        std.log.info("Depth checked for val {d} at level {d} and result is {d}", .{ self.val, level, res });
        return res;
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // const input = [2]u128{ 125, 17 };
    const input = [8]u128{ 8793800, 1629, 65, 5, 960, 0, 138983, 85629 };
    const blinks = 75;

    var chain_map = std.AutoHashMap(u128, *Chain).init(allocator);

    var frontier = std.ArrayList(*Chain).init(allocator);
    for (0..input.len) |i| {
        const chain = try allocator.create(Chain);
        chain.* = Chain.init(input[i]);
        try frontier.append(chain);
    }

    const stdout = std.io.getStdOut().writer();
    var count: usize = 0;
    for (0..blinks) |blink| {
        var blink_buf: [100]u8 = undefined;
        const blink_string = try std.fmt.bufPrint(&blink_buf, "Blink {d}/{d}\n", .{ blink, blinks });
        _ = try stdout.write(blink_string);
        const l = frontier.items.len - 1;
        std.log.info("Another blink with {d} items in frontier ", .{l});
        for (0..l + 1) |j| {
            count += 1;

            const chain = frontier.items[l - j];
            std.log.info("Iter {d} with {d} chains in map", .{ count, chain_map.count() });
            if (chain_map.get(chain.val)) |present| {
                chain.duplicate = present;
                _ = frontier.orderedRemove(l - j);
                // chain.parent = present;
                std.log.info("  [D] Found duplicate for {d}", .{present.*.val});
                continue;
            } else {
                std.log.info("  [N] First time seeing {d}", .{chain.*.val});
                try chain_map.put(chain.val, chain);
            }
            const next = try chain.step(allocator);
            if (next == null) {
                std.log.info("  [S] Split {d} into {d} & {d}", .{ chain.*.val, chain.*.left.?.val, chain.*.right.?.val });
                frontier.items[l - j] = chain.left.?;
                frontier.insert(l - j + 1, chain.right.?) catch |err| {
                    std.log.err("We hit an error {any}", .{err});
                };
            } else {
                std.log.info("  [U] Updated {d}->{d}", .{ chain.*.val, next.?.*.val });
                frontier.items[l - j] = next.?;
            }
        }
    }

    // mapping levels to maps, where the inner maps map key value to calculated depth
    var depth_map = std.AutoHashMap(usize, *std.AutoHashMap(u128, usize)).init(allocator);
    // var depth_frontier = std.ArrayList(u128).init(allocator);

    var sum: usize = 0;
    for (0..input.len) |i| {
        // try depth_frontier.append(input[i]);
        if (chain_map.get(input[i])) |chain| {
            const d = chain.get_depth(1);
            std.log.info("Depth for {d}={d}", .{ input[i], d });
            sum += d;
        } else {
            std.log.err("We have a problem v:{d}", .{input[i]});
        }
    }

    var b: [100]u8 = undefined;
    const s = try std.fmt.bufPrint(&b, "{d},{d}\n", .{ sum, 0 });
    _ = try stdout.write(s);
}
