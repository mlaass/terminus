const std = @import("std");
const testing = std.testing;
const builtin_env = @import("builtin_env.zig");
const Value = @import("term_interpreter.zig").Value;
const Environment = @import("term_interpreter.zig").Environment;
const evaluate = @import("term_interpreter.zig").evaluate;
const parse_to_tree = @import("term_parser.zig").parse_to_tree;
const InterpreterError = @import("term_interpreter.zig").InterpreterError;

// builtin_env = {
//     # math
//     "min": min,
//     "max": max,
//     "log": math.log,
//     "log1p": math.log1p,
//     "log2": math.log2,
//     "log10": math.log10,
//     "exp": math.exp,
//     "fsum": math.fsum,
//     "gcd": math.gcd,
//     "sqrt": math.sqrt,
//     "isqrt": math.isqrt,
//     "cos": math.cos,
//     "sin": math.sin,
//     "tan": math.tan,
//     "acos": math.acos,
//     "asin": math.asin,
//     "atan": math.atan,
//     "degrees": math.degrees,
//     "radians": math.radians,
//     "mean": builtin_mean,
//     "fmean": builtin_fmean,
//     "geometric_mean": builtin_geometric_mean,
//     "median": builtin_median,
//     "stdev": builtin_stdev,
//     "variance": builtin_variance,
//     "pi": math.pi,
//     "e": math.e,
//     "inf": math.inf,
//     "tau": math.tau,
//     "nan": math.nan,
//     # string functions:
//     "str.concat": builtin_concat,
//     "str.length": builtin_length,
//     "str.substring": builtin_substring,
//     "str.replace": builtin_replace,
//     "str.toUpper": builtin_to_upper,
//     "str.toLower": builtin_to_lower,
//     "str.trim": builtin_trim,
//     "str.split": builtin_split,
//     "str.indexOf": builtin_index_of,
//     "str.contains": builtin_contains,
//     "str.startsWith": builtin_starts_with,
//     "str.endsWith": builtin_ends_with,
//     "str.regexMatch": builtin_regex_match,
//     "str.format": builtin_format,
//     # date stuff
//     "date.parse": parse_iso_date,
//     "date.format": format_date,
//     "date.addDays": add_days,
//     "date.addHours": add_hours,
//     "date.addMinutes": add_minutes,
//     "date.addSeconds": add_seconds,
//     "date.dayOfWeek": day_of_week,
//     "date.dayOfMonth": day_of_month,
//     "date.dayOfYear": day_of_year,
//     "date.month": month_of_year,
//     "date.year": year_of_date,
//     "date.week": week_of_year,
//     # list stuff
//     "list.length": len,
//     "list.append": append_to_list,
//     "list.concat": concat_lists,
//     "list.get": list_get,
//     "list.put": list_put,
//     "list.slice": slice_list,
//     "list.map": list_map,
//     "list.filter": list_filter,
//     "apply": apply_function,
// }

fn expectEqualValue(expected: Value, actual: Value) !void {
    switch (expected.data) {
        .integer => |i| try testing.expectEqual(i, actual.data.integer),
        .float => |f| try testing.expectApproxEqAbs(f, actual.data.float, 0.0001),
        .boolean => |b| try testing.expectEqual(b, actual.data.boolean),
        .string => |s| try testing.expectEqualStrings(s, actual.data.string),
        .date => |d| try testing.expectEqualStrings(d, actual.data.date),
        .list => |l| {
            const actual_list = actual.data.list;
            try testing.expectEqual(l.len, actual_list.len);
            for (l, actual_list) |expected_item, actual_item| {
                try expectEqualValue(expected_item, actual_item);
            }
        },
        .function => try testing.expectEqual(expected.data.function, actual.data.function),
    }
}

// Helper to create test values
fn str(s: []const u8) Value {
    return Value{ .data = .{ .string = s } };
}

fn int(i: i64) Value {
    return Value{ .data = .{ .integer = i } };
}

fn float(f: f64) Value {
    return Value{ .data = .{ .float = f } };
}

fn boolean(b: bool) Value {
    return Value{ .data = .{ .boolean = b } };
}

fn list(allocator: std.mem.Allocator, items: []const Value) !Value {
    var new_list = try allocator.alloc(Value, items.len);
    @memcpy(new_list, items);
    return Value{ .data = .{ .list = new_list }, .allocator = allocator };
}

test "builtin arithmetic functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test basic arithmetic
    var tree_add = try parse_to_tree(allocator, "min(5, 3)");
    defer tree_add.deinit(allocator);
    var result = try evaluate(allocator, &tree_add.root, &env);
    try std.testing.expectEqual(.{ .integer = 3 }, result.data);

    // Test mixed types
    var tree_add_float = try parse_to_tree(allocator, "max(5.14, 3)");
    defer tree_add_float.deinit(allocator);
    result = try evaluate(allocator, &tree_add_float.root, &env);
    try std.testing.expectEqual(.{ .float = 5.14 }, result.data);

    // Test nested arithmetic
    var tree_mul = try parse_to_tree(allocator, "min(max(2, 3), mean(10, 5))");
    defer tree_mul.deinit(allocator);
    result = try evaluate(allocator, &tree_mul.root, &env);
    try std.testing.expectEqual(.{ .integer = 3 }, result.data);
}

test "builtin math functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test abs
    var tree_abs = try parse_to_tree(allocator, "abs(-42)");
    defer tree_abs.deinit(allocator);
    var result = try evaluate(allocator, &tree_abs.root, &env);
    try std.testing.expectEqual(.{ .integer = 42 }, result.data);

    // Test floor
    var tree_floor = try parse_to_tree(allocator, "floor(3.7)");
    defer tree_floor.deinit(allocator);
    result = try evaluate(allocator, &tree_floor.root, &env);
    try std.testing.expectEqual(.{ .float = 3.0 }, result.data);

    // Test ceil
    var tree_ceil = try parse_to_tree(allocator, "ceil(3.2)");
    defer tree_ceil.deinit(allocator);
    result = try evaluate(allocator, &tree_ceil.root, &env);
    try std.testing.expectEqual(.{ .float = 4.0 }, result.data);

    // Test complex expression
    var tree_add = try parse_to_tree(allocator, "floor(3.7) + ceil(2.2)");
    defer tree_add.deinit(allocator);
    result = try evaluate(allocator, &tree_add.root, &env);
    try std.testing.expectEqual(.{ .float = 6.0 }, result.data);
}

test "builtin type conversion functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test int conversion
    var tree = try parse_to_tree(allocator, "int(3.7)");
    defer tree.deinit(allocator);
    var result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(.{ .integer = 3 }, result.data);

    // Test float conversion
    var tree_float = try parse_to_tree(allocator, "float(42)");
    defer tree_float.deinit(allocator);
    result = try evaluate(allocator, &tree_float.root, &env);
    try std.testing.expectEqual(.{ .float = 42.0 }, result.data);

    // Test bool conversion
    var tree_bool = try parse_to_tree(allocator, "bool(1)");
    defer tree_bool.deinit(allocator);
    result = try evaluate(allocator, &tree_bool.root, &env);
    try std.testing.expectEqual(.{ .boolean = true }, result.data);

    var tree_bool_false = try parse_to_tree(allocator, "bool(0)");
    defer tree_bool_false.deinit(allocator);
    result = try evaluate(allocator, &tree_bool_false.root, &env);
    try std.testing.expectEqual(.{ .boolean = false }, result.data);
}

test "builtin function error cases" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test wrong number of arguments
    var tree = try parse_to_tree(allocator, "max()");
    defer tree.deinit(allocator);
    try std.testing.expectError(error.InvalidArgCount, evaluate(allocator, &tree.root, &env));

    // Test type errors
    var tree3 = try parse_to_tree(allocator, "max(1, 'not a number')");
    defer tree3.deinit(allocator);
    try std.testing.expectError(error.TypeError, evaluate(allocator, &tree3.root, &env));

    // Test division by zero
    var tree4 = try parse_to_tree(allocator, "1 / 0");
    defer tree4.deinit(allocator);
    try std.testing.expectError(error.DivisionByZero, evaluate(allocator, &tree4.root, &env));
}

test "builtin list functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test list creation and access
    var tree_get1 = try parse_to_tree(allocator, "list.get([1, 2, 3], 1)");
    defer tree_get1.deinit(allocator);
    var result = try evaluate(allocator, &tree_get1.root, &env);
    std.debug.print("result: {any}\n", .{result.data});
    try std.testing.expectEqual(.{ .integer = 2 }, result.data);

    // Test list length
    var tree_length = try parse_to_tree(allocator, "list.length([1, 2, 3])");
    defer tree_length.deinit(allocator);
    var result_length = try evaluate(allocator, &tree_length.root, &env);
    defer result_length.deinit();
    std.debug.print("result: {any}\n", .{result_length.data});
    try std.testing.expectEqual(.{ .integer = 3 }, result_length.data);

    // Test nested lists
    var tree_nested = try parse_to_tree(allocator, "list.get([1, [2, 3], 4], 1)");
    defer tree_nested.deinit(allocator);
    var result_nested = try evaluate(allocator, &tree_nested.root, &env);
    defer result_nested.deinit();
    std.debug.print("result: [{any}, {any}]\n", .{ result_nested.data.list[0].data, result_nested.data.list[1].data });

    // Compare the values
    try std.testing.expectEqual(@as(usize, 2), result_nested.data.list.len);
    try std.testing.expectEqual(.{ .integer = 2 }, result_nested.data.list[0].data);
    try std.testing.expectEqual(.{ .integer = 3 }, result_nested.data.list[1].data);

    // Test list append
    var tree_append = try parse_to_tree(allocator, "list.append( [2, 3], 1)");
    defer tree_append.deinit(allocator);
    var result_append = try evaluate(allocator, &tree_append.root, &env);
    defer result_append.deinit();
    try std.testing.expectEqual(.{ .integer = 2 }, result_append.data.list[0].data);
    try std.testing.expectEqual(.{ .integer = 3 }, result_append.data.list[1].data);
    try std.testing.expectEqual(.{ .integer = 1 }, result_append.data.list[2].data);
}

// String function tests
test "str.concat" {
    const allocator = testing.allocator;

    // Test basic string concatenation
    {
        const args = [_]Value{ str("Hello"), str(" "), str("World") };
        const result = try builtin_env.functions.get("str.concat").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("Hello World"), result);
    }

    // Test mixed type concatenation
    {
        const args = [_]Value{ str("Count: "), int(42), str(", Value: "), float(3.14) };
        const result = try builtin_env.functions.get("str.concat").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("Count: 42, Value: 3.14"), result);
    }

    // Test empty string
    {
        const args = [_]Value{str("")};
        const result = try builtin_env.functions.get("str.concat").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str(""), result);
    }
}

test "str.length" {
    const allocator = testing.allocator;

    // Test normal string
    {
        const args = [_]Value{str("Hello")};
        const result = try builtin_env.functions.get("str.length").?(allocator, &args);
        try expectEqualValue(int(5), result);
    }

    // Test empty string
    {
        const args = [_]Value{str("")};
        const result = try builtin_env.functions.get("str.length").?(allocator, &args);
        try expectEqualValue(int(0), result);
    }

    // Test unicode string
    {
        const args = [_]Value{str("Hello 🌍")};
        const result = try builtin_env.functions.get("str.length").?(allocator, &args);
        try expectEqualValue(int(8), result); // Note: counts bytes, not graphemes
    }
}

test "str.substring" {
    const allocator = testing.allocator;

    // Test normal substring
    {
        const args = [_]Value{ str("Hello World"), int(0), int(5) };
        var result = try builtin_env.functions.get("str.substring").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("Hello"), result);
    }

    // Test empty substring
    {
        const args = [_]Value{ str("Hello"), int(1), int(1) };
        var result = try builtin_env.functions.get("str.substring").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str(""), result);
    }

    // Test error cases
    {
        const args = [_]Value{ str("Hello"), int(3), int(1) };
        try testing.expectError(error.InvalidOperation, builtin_env.functions.get("str.substring").?(allocator, &args));
    }
}

test "str.replace" {
    const allocator = testing.allocator;

    // Test basic replacement
    {
        const args = [_]Value{ str("Hello World"), str("World"), str("Zig") };
        var result = try builtin_env.functions.get("str.replace").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("Hello Zig"), result);
    }

    // Test multiple replacements
    {
        const args = [_]Value{ str("ha ha ha"), str("ha"), str("he") };
        var result = try builtin_env.functions.get("str.replace").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("he he he"), result);
    }

    // Test no matches
    {
        const args = [_]Value{ str("Hello"), str("xyz"), str("abc") };
        var result = try builtin_env.functions.get("str.replace").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("Hello"), result);
    }
}

test "str.toUpper and str.toLower" {
    const allocator = testing.allocator;

    // Test toUpper
    {
        const args = [_]Value{str("Hello World")};
        var result = try builtin_env.functions.get("str.toUpper").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("HELLO WORLD"), result);
    }

    // Test toLower
    {
        const args = [_]Value{str("Hello World")};
        var result = try builtin_env.functions.get("str.toLower").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("hello world"), result);
    }

    // Test mixed case
    {
        const args = [_]Value{str("hElLo WoRlD")};
        var upper_result = try builtin_env.functions.get("str.toUpper").?(allocator, &args);
        defer upper_result.deinit();
        try expectEqualValue(str("HELLO WORLD"), upper_result);

        var lower_result = try builtin_env.functions.get("str.toLower").?(allocator, &args);
        defer lower_result.deinit();
        try expectEqualValue(str("hello world"), lower_result);
    }
}

test "str.trim" {
    const allocator = testing.allocator;

    // Test basic trimming
    {
        const args = [_]Value{str("  Hello World  ")};
        var result = try builtin_env.functions.get("str.trim").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("Hello World"), result);
    }

    // Test already trimmed
    {
        const args = [_]Value{str("Hello")};
        var result = try builtin_env.functions.get("str.trim").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str("Hello"), result);
    }

    // Test all whitespace
    {
        const args = [_]Value{str("   \t\n\r  ")};
        var result = try builtin_env.functions.get("str.trim").?(allocator, &args);
        defer result.deinit();
        try expectEqualValue(str(""), result);
    }
}

test "list.concat" {
    const allocator = testing.allocator;

    // Test basic concatenation
    {
        var list1 = [_]Value{ int(1), int(2) };
        var list2 = [_]Value{ int(3), int(4) };
        const args = [_]Value{
            Value{ .data = .{ .list = &list1 } },
            Value{ .data = .{ .list = &list2 } },
        };
        var result = try builtin_env.functions.get("list.concat").?(allocator, &args);
        defer result.deinit();

        try testing.expectEqual(@as(usize, 4), result.data.list.len);
        try testing.expectEqual(@as(i64, 1), result.data.list[0].data.integer);
        try testing.expectEqual(@as(i64, 2), result.data.list[1].data.integer);
        try testing.expectEqual(@as(i64, 3), result.data.list[2].data.integer);
        try testing.expectEqual(@as(i64, 4), result.data.list[3].data.integer);
    }

    // Test empty list concatenation
    {
        var empty_list = [_]Value{};
        var list2 = [_]Value{ int(1), int(2) };
        const args = [_]Value{
            Value{ .data = .{ .list = &empty_list } },
            Value{ .data = .{ .list = &list2 } },
        };
        var result = try builtin_env.functions.get("list.concat").?(allocator, &args);
        defer result.deinit();

        try testing.expectEqual(@as(usize, 2), result.data.list.len);
        try testing.expectEqual(@as(i64, 1), result.data.list[0].data.integer);
        try testing.expectEqual(@as(i64, 2), result.data.list[1].data.integer);
    }
}

test "list.slice" {
    const allocator = testing.allocator;

    // Test normal slice
    {
        var test_list = [_]Value{ int(1), int(2), int(3), int(4), int(5) };
        const args = [_]Value{
            Value{ .data = .{ .list = &test_list } },
            int(1),
            int(4),
        };
        var result = try builtin_env.functions.get("list.slice").?(allocator, &args);
        defer result.deinit();

        try testing.expectEqual(@as(usize, 3), result.data.list.len);
        try testing.expectEqual(@as(i64, 2), result.data.list[0].data.integer);
        try testing.expectEqual(@as(i64, 3), result.data.list[1].data.integer);
        try testing.expectEqual(@as(i64, 4), result.data.list[2].data.integer);
    }

    // Test empty slice
    {
        var test_list = [_]Value{ int(1), int(2), int(3) };
        const args = [_]Value{
            Value{ .data = .{ .list = &test_list } },
            int(1),
            int(1),
        };
        var result = try builtin_env.functions.get("list.slice").?(allocator, &args);
        defer result.deinit();

        try testing.expectEqual(@as(usize, 0), result.data.list.len);
    }

    // Test error cases
    {
        var test_list = [_]Value{ int(1), int(2), int(3) };
        const args = [_]Value{
            Value{ .data = .{ .list = &test_list } },
            int(2),
            int(1),
        };
        try testing.expectError(error.InvalidOperation, builtin_env.functions.get("list.slice").?(allocator, &args));
    }
}

test "list.map" {
    const allocator = testing.allocator;

    // Helper function to double a number
    const double = struct {
        fn func(args: []const Value) InterpreterError!Value {
            if (args.len != 1) return error.InvalidArgCount;
            return switch (args[0].data) {
                .integer => |i| Value{ .data = .{ .integer = i * 2 } },
                else => error.TypeError,
            };
        }
    }.func;

    // Test mapping over integers
    {
        var test_list = [_]Value{ int(1), int(2), int(3) };
        const args = [_]Value{
            Value{ .data = .{ .list = &test_list } },
            Value{ .data = .{ .function = double } },
        };
        var result = try builtin_env.functions.get("list.map").?(allocator, &args);
        defer result.deinit();

        try testing.expectEqual(@as(usize, 3), result.data.list.len);
        try testing.expectEqual(@as(i64, 2), result.data.list[0].data.integer);
        try testing.expectEqual(@as(i64, 4), result.data.list[1].data.integer);
        try testing.expectEqual(@as(i64, 6), result.data.list[2].data.integer);
    }
}

test "list.filter" {
    const allocator = testing.allocator;

    // Helper function to check if a number is even
    const is_even = struct {
        fn func(args: []const Value) InterpreterError!Value {
            if (args.len != 1) return error.InvalidArgCount;
            return switch (args[0].data) {
                .integer => |i| Value{ .data = .{ .boolean = @rem(i, 2) == 0 } },
                else => error.TypeError,
            };
        }
    }.func;

    // Test filtering integers
    {
        var test_list = [_]Value{ int(1), int(2), int(3), int(4), int(5), int(6) };
        const args = [_]Value{
            Value{ .data = .{ .list = &test_list } },
            Value{ .data = .{ .function = is_even } },
        };
        var result = try builtin_env.functions.get("list.filter").?(allocator, &args);
        defer result.deinit();

        try testing.expectEqual(@as(usize, 3), result.data.list.len);
        try testing.expectEqual(@as(i64, 2), result.data.list[0].data.integer);
        try testing.expectEqual(@as(i64, 4), result.data.list[1].data.integer);
        try testing.expectEqual(@as(i64, 6), result.data.list[2].data.integer);
    }
}
