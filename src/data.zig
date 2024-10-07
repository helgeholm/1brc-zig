const std = @import("std");

const mapSize = 16384;

pub const Results = struct {
    data: std.StringHashMapUnmanaged(StationData),
    pub const empty: @This() = .{
        .data = std.StringHashMapUnmanaged(StationData).empty,
    };
    pub fn init(self: *Results, allocator: std.mem.Allocator) !void {
        try self.data.ensureTotalCapacity(allocator, mapSize);
    }
    pub fn deinit(self: *Results, allocator: std.mem.Allocator) void {
        self.data.deinit(allocator);
        self.* = undefined;
    }
};

pub const StationData = struct {
    sum: i39,
    min: i11,
    max: i11,
    count: u30,
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
    v: i11,
    pub fn format(self: Decimal2, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const i = @divTrunc(self.v, 10);
        const r = @mod(self.v, 10);
        try writer.print("{d}.{d}", .{ i, r });
    }
};
