const std = @import("std");
const Value = @import("term_interpreter.zig").Value;
const Environment = @import("term_interpreter.zig").Environment;
const evaluate = @import("term_interpreter.zig").evaluate;
const parse_to_tree = @import("term_parser.zig").parse_to_tree;

test "builtin arithmetic functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test basic arithmetic
    var tree = try parse_to_tree(allocator, "add(5, 3)");
    defer tree.deinit(allocator);
    var result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 8 }, result);

    // Test mixed types
    tree = try parse_to_tree(allocator, "add(5, 3.14)");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .float = 8.14 }, result);

    // Test nested arithmetic
    tree = try parse_to_tree(allocator, "mul(add(2, 3), sub(10, 5))");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 25 }, result);
}

test "builtin math functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test abs
    var tree = try parse_to_tree(allocator, "abs(-42)");
    defer tree.deinit(allocator);
    var result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 42 }, result);

    // Test floor
    tree = try parse_to_tree(allocator, "floor(3.7)");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 3 }, result);

    // Test ceil
    tree = try parse_to_tree(allocator, "ceil(3.2)");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 4 }, result);

    // Test complex expression
    tree = try parse_to_tree(allocator, "add(floor(3.7), ceil(2.2))");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 6 }, result);
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
    tree = try parse_to_tree(allocator, "float(42)");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .float = 42.0 }, result);

    // Test bool conversion
    tree = try parse_to_tree(allocator, "bool(1)");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    tree = try parse_to_tree(allocator, "bool(0)");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .boolean = false }, result);
}

test "builtin function error cases" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test wrong number of arguments
    var tree = try parse_to_tree(allocator, "add(1)");
    defer tree.deinit(allocator);
    try std.testing.expectError(error.InvalidArgCount, evaluate(allocator, &tree.root, &env));

    // Test type errors
    tree = try parse_to_tree(allocator, "add(1, 'not a number')");
    defer tree.deinit(allocator);
    try std.testing.expectError(error.TypeError, evaluate(allocator, &tree.root, &env));

    // Test division by zero
    tree = try parse_to_tree(allocator, "div(1, 0)");
    defer tree.deinit(allocator);
    try std.testing.expectError(error.DivisionByZero, evaluate(allocator, &tree.root, &env));
}

test "builtin list functions" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Test list creation and access
    var tree = try parse_to_tree(allocator, "get([1, 2, 3], 1)");
    defer tree.deinit(allocator);
    var result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 2 }, result);

    // Test list length
    tree = try parse_to_tree(allocator, "len([1, 2, 3])");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .integer = 3 }, result);

    // Test nested lists
    tree = try parse_to_tree(allocator, "get([1, [2, 3], 4], 1)");
    defer tree.deinit(allocator);
    result = try evaluate(allocator, &tree.root, &env);

    // Create expected list value
    var expected_list = try allocator.alloc(Value, 2);
    defer allocator.free(expected_list);
    expected_list[0] = Value{ .integer = 2 };
    expected_list[1] = Value{ .integer = 3 };

    // Compare the values
    try std.testing.expectEqual(@as(usize, 2), result.list.len);
    try std.testing.expectEqual(Value{ .integer = 2 }, result.list[0]);
    try std.testing.expectEqual(Value{ .integer = 3 }, result.list[1]);
}
