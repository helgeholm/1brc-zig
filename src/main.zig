const std = @import("std");

const StationData = struct {
    sum: i64,
    min: i16,
    max: i16,
    count: u32,
    pub fn format(self: StationData, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const mean: Decimal2 = .{ .v = @intCast(@divTrunc(@divTrunc(self.sum * 10, self.count) + 5, 10)) };
        const min: Decimal2 = .{ .v = self.min };
        const max: Decimal2 = .{ .v = self.max };
        try writer.print("{};{};{}", .{ min, mean, max });
    }
};

const Decimal2 = struct {
    v: i16,
    pub fn format(self: Decimal2, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const i = @divTrunc(self.v, 10);
        const r = @mod(self.v, 10);
        try writer.print("{d}.{d}", .{ i, r });
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();
    const file = try std.fs.cwd().openFile("measurements.txt", .{});
    defer file.close();
    const stat = try file.stat();
    const buf = try std.posix.mmap(null, stat.size, std.os.linux.PROT.READ, std.posix.system.MAP{ .TYPE = std.posix.system.MAP_TYPE.SHARED, .POPULATE = true }, file.handle, 0);
    defer std.posix.munmap(buf);

    const stdout = std.io.getStdOut().writer();

    var results = std.StringHashMapUnmanaged(StationData).empty;
    try results.ensureTotalCapacity(allocator, 65536);
    // var results = std.StringHashMap(StationData).init(fixedAllocator.allocator());
    sumStations(&results, buf);
    // try stdout.print("{}\n", .{results.count()});
    var it = results.iterator();
    while (it.next()) |entry| {
        try stdout.print("{s};{}\n", .{ entry.key_ptr.*, entry.value_ptr });
    }
}

fn sumStations(results: anytype, buf: []u8) void {
    var nameStart: u64 = 0;
    for (buf, 0..) |b, i| {
        if (b == '\n') {
            processLine(results, buf[nameStart..i]);
            nameStart = i + 1;
        }
    }
}

fn processLine(results: anytype, line: []u8) void {
    const sep = if (line[line.len - 6] == ';') line.len - 6 else if (line[line.len - 5] == ';') line.len - 5 else line.len - 4;
    const valHi = std.fmt.parseInt(i16, line[sep + 1 .. line.len - 2], 10) catch unreachable;
    const val = 10 * valHi + line[line.len - 1] - '0';
    var gopResult = results.getOrPutAssumeCapacity(line[0..sep]);
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
