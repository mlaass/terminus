const std = @import("std");
const Value = @import("term_interpreter.zig").Value;
const Environment = @import("term_interpreter.zig").Environment;
const evaluate = @import("term_interpreter.zig").evaluate;
const parse_to_tree = @import("term_parser.zig").parse_to_tree;

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

test "builtin arithmetic functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test basic arithmetic
    var tree_add = try parse_to_tree(allocator, "min(5, 3)");
    defer tree_add.deinit(allocator);
    var result = try evaluate(allocator, &tree_add.root, &env);
    try std.testing.expectEqual(Value{ .integer = 3 }, result);

    // Test mixed types
    var tree_add_float = try parse_to_tree(allocator, "max(5.14, 3)");
    defer tree_add_float.deinit(allocator);
    result = try evaluate(allocator, &tree_add_float.root, &env);
    try std.testing.expectEqual(Value{ .float = 5.14 }, result);

    // Test nested arithmetic
    var tree_mul = try parse_to_tree(allocator, "min(max(2, 3), mean(10, 5))");
    defer tree_mul.deinit(allocator);
    result = try evaluate(allocator, &tree_mul.root, &env);
    try std.testing.expectEqual(Value{ .integer = 3 }, result);
}

test "builtin math functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test abs
    var tree_abs = try parse_to_tree(allocator, "abs(-42)");
    defer tree_abs.deinit(allocator);
    var result = try evaluate(allocator, &tree_abs.root, &env);
    try std.testing.expectEqual(Value{ .integer = 42 }, result);

    // Test floor
    var tree_floor = try parse_to_tree(allocator, "floor(3.7)");
    defer tree_floor.deinit(allocator);
    result = try evaluate(allocator, &tree_floor.root, &env);
    try std.testing.expectEqual(Value{ .float = 3.0 }, result);

    // Test ceil
    var tree_ceil = try parse_to_tree(allocator, "ceil(3.2)");
    defer tree_ceil.deinit(allocator);
    result = try evaluate(allocator, &tree_ceil.root, &env);
    try std.testing.expectEqual(Value{ .float = 4.0 }, result);

    // Test complex expression
    var tree_add = try parse_to_tree(allocator, "floor(3.7) + ceil(2.2)");
    defer tree_add.deinit(allocator);
    result = try evaluate(allocator, &tree_add.root, &env);
    try std.testing.expectEqual(Value{ .float = 6.0 }, result);
}

test "builtin type conversion functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test int conversion
    var tree = try parse_to_tree(allocator, "int(3.7)");
    defer tree.deinit(allocator);
    var result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 3 }, result);

    // Test float conversion
    var tree_float = try parse_to_tree(allocator, "float(42)");
    defer tree_float.deinit(allocator);
    result = try evaluate(allocator, &tree_float.root, &env);
    try std.testing.expectEqual(Value{ .float = 42.0 }, result);

    // Test bool conversion
    var tree_bool = try parse_to_tree(allocator, "bool(1)");
    defer tree_bool.deinit(allocator);
    result = try evaluate(allocator, &tree_bool.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    var tree_bool_false = try parse_to_tree(allocator, "bool(0)");
    defer tree_bool_false.deinit(allocator);
    result = try evaluate(allocator, &tree_bool_false.root, &env);
    try std.testing.expectEqual(Value{ .boolean = false }, result);
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
    var tree_get1 = try parse_to_tree(allocator, "list.get(1,[1, 2, 3])");
    defer tree_get1.deinit(allocator);
    var result = try evaluate(allocator, &tree_get1.root, &env);
    std.debug.print("result: {any}\n", .{result});
    try std.testing.expectEqual(Value{ .integer = 2 }, result);

    // Test list length
    var tree_length = try parse_to_tree(allocator, "list.length([1, 2, 3])");
    defer tree_length.deinit(allocator);
    result = try evaluate(allocator, &tree_length.root, &env);
    try std.testing.expectEqual(Value{ .integer = 3 }, result);

    // Test nested lists
    var tree_get2 = try parse_to_tree(allocator, "list.get(1,[1, [2, 3], 4])");
    defer tree_get2.deinit(allocator);
    result = try evaluate(allocator, &tree_get2.root, &env);
    std.debug.print("result: {any}\n", .{result});

    // Compare the values
    try std.testing.expectEqual(@as(usize, 2), result.list.len);
    try std.testing.expectEqual(Value{ .integer = 2 }, result.list[0]);
    try std.testing.expectEqual(Value{ .integer = 3 }, result.list[1]);
}
