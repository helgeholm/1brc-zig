const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("measurements_10M.txt", .{});
    defer file.close();
    const stat = try file.stat();
    const buf = try std.posix.mmap(null, stat.size, std.os.linux.PROT.READ, std.posix.system.MAP{ .TYPE = std.posix.system.MAP_TYPE.SHARED, .POPULATE = true }, file.handle, 0);
    defer std.posix.munmap(buf);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const lines = countLines(buf);
    try stdout.print("{d} lines\n", .{lines});
    try bw.flush();
}

fn countLines(buf: []u8) u64 {
    var count: u64 = 0;
    for (buf, 0..) |b, i| {
        if (b == '\n') {
            count += i;
        }
    }
    return count;
}
