const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    if (std.os.argv.len != 4) {
        std.debug.print("Usage: {s} NUMBER IN_BASE TO_BASE\n", .{std.os.argv[0]});
        std.os.exit(1);
    }
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var arg_it = std.process.ArgIterator.init();
    defer arg_it.deinit();
    _ = arg_it.skip();

    const result = base_to_base(allocator, arg_it.next().?, arg_it.next().?, arg_it.next().?) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        std.os.exit(1);
    };
    std.debug.print("{s}\n", .{result});
    allocator.free(result);
}

pub fn base_to_base(allocator: std.mem.Allocator, nbr: []const u8, from_base: []const u8, to_base: []const u8) (ConversionError || Allocator.Error)![]u8 {
    const result = try base_to_decimal(nbr, from_base);
    return try decimal_to_base(allocator, result, to_base);
}

test "base_to_base" {
    {
        const result = try base_to_base(std.testing.allocator, "1100101011111110", "01", "0123456789ABCDEF");
        defer std.testing.allocator.free(result);
        try expect(std.mem.eql(u8, result, "CAFE"));
    }
}

const ConversionError = CheckBaseError || error{
    CharacterNotFoundInBase,
} || error{ Overflow, Underflow };

pub fn base_to_decimal(nbr: []const u8, from_base: []const u8) ConversionError!usize {
    try check_base(from_base);
    var result: usize = 0;
    var i = nbr.len;
    for (nbr) |c| {
        const x = for (from_base, 0..from_base.len) |c2, j| {
            if (c == c2) break j;
        } else {
            return ConversionError.CharacterNotFoundInBase;
        };
        i -= 1;
        result += x * try std.math.powi(usize, from_base.len, i);
    }
    return result;
}

test "base_to_decimal" {
    try expect(try base_to_decimal("CAFE", "0123456789ABCDEF") == 51966);
}

pub fn decimal_to_base(allocator: Allocator, nbr: usize, to_base: []const u8) (ConversionError || Allocator.Error)![]u8 {
    try check_base(to_base);
    if (nbr == 0) {
        var result = try allocator.alloc(u8, 1);
        @memcpy(result, to_base[0..1]);
        return result;
    }
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();
    var n = nbr;
    while (n > 0) {
        const x = n % to_base.len;
        n /= to_base.len;
        try result.append(to_base[x]);
    }
    var ret = try result.toOwnedSlice();
    std.mem.reverse(u8, ret);
    return ret;
}

test "decimal_to_base" {
    {
        const result = try decimal_to_base(std.testing.allocator, 0, "981");
        defer std.testing.allocator.free(result);
        try expect(std.mem.eql(u8, result, "9"));
    }
    {
        const result = try decimal_to_base(std.testing.allocator, 51966, "0123456789ABCDEF");
        defer std.testing.allocator.free(result);
        try expect(std.mem.eql(u8, result, "CAFE"));
    }
}

const CheckBaseError = error{
    BaseLengthTooShort,
    DuplicateCharacterInBase,
};

pub fn check_base(base: []const u8) CheckBaseError!void {
    if (base.len < 2) {
        return error.BaseLengthTooShort;
    }

    for (base, 0..) |c, i| {
        for (base[i + 1 ..]) |c2| {
            if (c == c2) {
                return error.DuplicateCharacterInBase;
            }
        }
    }
}

test "check_base" {
    try check_base("01");
    try expectError(CheckBaseError.DuplicateCharacterInBase, check_base("00"));
    try expectError(CheckBaseError.DuplicateCharacterInBase, check_base("001"));
    try expectError(CheckBaseError.BaseLengthTooShort, check_base("x"));
}
