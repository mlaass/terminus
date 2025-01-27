const std = @import("std");
const Value = @import("term_interpreter.zig").Value;
const Allocator = std.mem.Allocator;

// Helper function to convert Value to f64
fn valueToFloat(value: Value) !f64 {
    return switch (value) {
        .integer => |i| @as(f64, @floatFromInt(i)),
        .float => |f| f,
        else => error.TypeError,
    };
}

// Math functions
fn min(args: []const Value) !Value {
    if (args.len < 1) return error.InvalidArgCount;
    var min_val = try valueToFloat(args[0]);
    for (args[1..]) |arg| {
        const val = try valueToFloat(arg);
        min_val = @min(min_val, val);
    }
    return Value{ .float = min_val };
}

fn max(args: []const Value) !Value {
    if (args.len < 1) return error.InvalidArgCount;
    var max_val = try valueToFloat(args[0]);
    for (args[1..]) |arg| {
        const val = try valueToFloat(arg);
        max_val = @max(max_val, val);
    }
    return Value{ .float = max_val };
}

fn sqrt(args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return Value{ .float = @sqrt(x) };
}

// String functions
fn strConcat(args: []const Value) !Value {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    for (args) |arg| {
        switch (arg) {
            .string => |s| try buf.appendSlice(s),
            .integer => |i| try std.fmt.format(buf.writer(), "{d}", .{i}),
            .float => |f| try std.fmt.format(buf.writer(), "{d}", .{f}),
            .boolean => |b| try std.fmt.format(buf.writer(), "{}", .{b}),
            else => return error.TypeError,
        }
    }

    return Value{ .string = try buf.toOwnedSlice() };
}

fn strLength(args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgCount;
    const str = switch (args[0]) {
        .string => |s| s,
        else => return error.TypeError,
    };
    return Value{ .integer = @intCast(str.len) };
}

// Date functions
fn dateAddDays(args: []const Value) !Value {
    if (args.len != 2) return error.InvalidArgCount;
    const date_str = switch (args[0]) {
        .date => |d| d,
        else => return error.TypeError,
    };
    // const days = switch (args[1]) {
    //     .integer => |i| i,
    //     else => return error.TypeError,
    // };

    // Parse date, add days, format result
    var buf: [64]u8 = undefined;
    // TODO: Implement actual date arithmetic
    return Value{ .date = try std.fmt.bufPrint(&buf, "{s}", .{date_str}) };
}

// List functions
fn listLength(args: []const Value) !Value {
    if (args.len != 1) return error.InvalidArgCount;
    const list = switch (args[0]) {
        .list => |l| l,
        else => return error.TypeError,
    };
    return Value{ .integer = @intCast(list.len) };
}

fn listAppend(args: []const Value) !Value {
    if (args.len != 2) return error.InvalidArgCount;
    const list = switch (args[0]) {
        .list => |l| l,
        else => return error.TypeError,
    };

    var new_list = try allocator.alloc(Value, list.len + 1);
    @memcpy(new_list[0..list.len], list);
    new_list[list.len] = args[1];

    return Value{ .list = new_list };
}

// Environment setup
var allocator: Allocator = undefined;

pub fn init(alloc: Allocator) void {
    allocator = alloc;
}

// Function lookup table
const BuiltinFn = *const fn ([]const Value) anyerror!Value;

pub const builtins = std.ComptimeStringMap(BuiltinFn, .{
    // Math functions
    .{ "min", min },
    .{ "max", max },
    .{ "sqrt", sqrt },

    // String functions
    .{ "str.concat", strConcat },
    .{ "str.length", strLength },

    // Date functions
    .{ "date.addDays", dateAddDays },

    // List functions
    .{ "list.length", listLength },
    .{ "list.append", listAppend },
});

pub fn get(name: []const u8) ?BuiltinFn {
    return builtins.get(name);
}
