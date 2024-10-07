const std = @import("std");
const data = @import("data.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const file = try std.fs.cwd().openFile("measurements.txt", .{});
    defer file.close();
    const stat = try file.stat();
    const buf = try std.posix.mmap(null, stat.size, std.os.linux.PROT.READ, std.posix.system.MAP{ .TYPE = std.posix.system.MAP_TYPE.SHARED, .POPULATE = true }, file.handle, 0);
    defer std.posix.munmap(buf);
    var results = data.Results.empty;
    try results.init(allocator);
    defer results.deinit(allocator);
    try sumStationsParallel(&results, buf, 16, allocator);
    var it = results.data.iterator();
    while (it.next()) |entry| {
        std.debug.print("{s};{}\n", .{ entry.key_ptr.*, entry.value_ptr });
    }
}

fn sumStationsParallel(results: *data.Results, buf: []u8, numPartitions: usize, allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arenaAllocator = arena.allocator();
    var partResults = try arenaAllocator.alloc(data.Results, numPartitions);
    var threads = try arenaAllocator.alloc(std.Thread, numPartitions);
    const partitionSize = @divTrunc(buf.len, numPartitions);
    var start: usize = 0;
    for (0..numPartitions) |i| {
        var end = @min(start + partitionSize, buf.len);
        while (buf[end - 1] != '\n') {
            end += 1;
        }
        partResults[i] = data.Results.empty;
        try partResults[i].init(arenaAllocator);
        threads[i] = try std.Thread.spawn(.{ .stack_size = 8192 }, sumStations, .{ &partResults[i], buf[start..end] });
        start = end;
    }
    for (0..numPartitions) |i| {
        threads[i].join();
        var it = partResults[i].data.iterator();
        while (it.next()) |entry| {
            var gopResult = results.data.getOrPutAssumeCapacity(entry.key_ptr.*);
            if (gopResult.found_existing) {
                gopResult.value_ptr.sum += entry.value_ptr.sum;
                gopResult.value_ptr.min = @min(gopResult.value_ptr.min, entry.value_ptr.min);
                gopResult.value_ptr.max = @max(gopResult.value_ptr.max, entry.value_ptr.max);
                gopResult.value_ptr.count += entry.value_ptr.count;
            } else {
                gopResult.value_ptr.* = entry.value_ptr.*;
            }
        }
    }
}

fn sumStations(results: *data.Results, buf: []u8) void {
    var nameStart: u64 = 0;
    for (buf, 0..) |b, i| {
        if (b == '\n') {
            processLine(results, buf[nameStart..i]);
            nameStart = i + 1;
        }
    }
}

fn processLine(results: *data.Results, line: []u8) void {
    const sep = if (line[line.len - 6] == ';') line.len - 6 else if (line[line.len - 5] == ';') line.len - 5 else line.len - 4;
    const valHi = std.fmt.parseInt(i16, line[sep + 1 .. line.len - 2], 10) catch unreachable;
    const val = 10 * valHi + line[line.len - 1] - '0';
    var gopResult = results.data.getOrPutAssumeCapacity(line[0..sep]);
    if (gopResult.found_existing) {
        gopResult.value_ptr.sum += @intCast(val);
        gopResult.value_ptr.min = @min(gopResult.value_ptr.min, val);
        gopResult.value_ptr.max = @max(gopResult.value_ptr.max, val);
        gopResult.value_ptr.count += 1;
    } else {
        gopResult.value_ptr.sum = @intCast(val);
        gopResult.value_ptr.min = val;
        gopResult.value_ptr.max = val;
        gopResult.value_ptr.count = 1;
    }
}
