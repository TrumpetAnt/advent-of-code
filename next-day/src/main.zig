const std = @import("std");
const Child = std.process.Child;
const cURL = @cImport({
    @cInclude("curl/curl.h");
});

pub fn main() !void {
    const day = try findNextDay();
    if (day > 99 or day < -9) {
        return;
    }
    const max_len = 6;
    var buf: [max_len]u8 = undefined;
    const dir_name = try std.fmt.bufPrint(&buf, "day-{}", .{day});
    try createNextDayDir(dir_name);
    try initZigProject(dir_name);

    // try fetchInputForDay(day, dir_name);
}

fn writeToArrayListCallback(data: *anyopaque, size: c_uint, nmemb: c_uint, user_data: *anyopaque) callconv(.C) c_uint {
    var buffer: *std.ArrayList(u8) = @alignCast(@ptrCast(user_data));
    var typed_data: [*]u8 = @ptrCast(data);
    buffer.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
    return nmemb * size;
}

fn writeToFile(data: []u8, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(
        path,
        .{ .read = true },
    );
    defer file.close();

    const bytes_written = try file.writeAll(data);
    _ = bytes_written;
}

fn findNextDay() !i32 {
    var iter = (try std.fs.cwd().openDir(
        ".",
        .{ .iterate = true },
    )).iterate();
    const needle = "day-";
    var max: i32 = 0;
    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                if (std.mem.indexOf(u8, entry.name, needle)) |_| {
                    const integer = try std.fmt.parseInt(i32, entry.name[4..], 10);
                    if (max < integer) {
                        max = integer;
                    }
                }
            },
            else => {},
        }
    }

    return max + 1;
}

fn createNextDayDir(dir_name: []u8) !void {
    std.log.info("Creating dir: {s}", .{dir_name});
    try std.fs.cwd().makeDir(dir_name);
}

fn initZigProject(dir_name: []u8) !void {
    std.log.info("Initializing zig project", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const argv = [_][]const u8{ "zig", "init" };

    var child = Child.init(&argv, allocator);
    child.cwd = dir_name;

    try child.spawn();
    _ = try child.wait();
}

fn fetchInputForDay(day: i32, dir_name: []u8) !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena_state.deinit();

    const allocator = arena_state.allocator();

    if (cURL.curl_global_init(cURL.CURL_GLOBAL_ALL) != cURL.CURLE_OK)
        return error.CURLGlobalInitFailed;
    defer cURL.curl_global_cleanup();

    const handle = cURL.curl_easy_init() orelse return error.CURLHandleInitFailed;
    defer cURL.curl_easy_cleanup(handle);

    var response_buffer = std.ArrayList(u8).init(allocator);

    defer response_buffer.deinit();

    const url_len = 42;
    var url_buf: [url_len]u8 = std.mem.zeroes([url_len]u8);
    _ = try std.fmt.bufPrint(&url_buf, "https://adventofcode.com/2024/day/{d}/input", .{day});

    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_URL, &url_buf) != cURL.CURLE_OK)
        return error.CouldNotSetURL;

    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEFUNCTION, writeToArrayListCallback) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEDATA, &response_buffer) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;

    std.log.info("Performing request: {s}", .{url_buf});
    if (cURL.curl_easy_perform(handle) != cURL.CURLE_OK)
        return error.FailedToPerformRequest;

    const x = 16;
    var second_buf: [x]u8 = undefined;
    const path = try std.fmt.bufPrint(&second_buf, "{s}/input.txt", .{dir_name});
    try writeToFile(response_buffer.items, path);
}
