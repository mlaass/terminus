const std = @import("std");
const Environment = @import("term_interpreter.zig").Environment;
const Value = @import("term_interpreter.zig").Value;
const parse_to_tree = @import("term_parser.zig").parse_to_tree;
const evaluate = @import("term_interpreter.zig").evaluate;
const deinitValue = @import("term_interpreter.zig").deinitValue;

test "evaluate simple expression" {
    const allocator = std.testing.allocator;

    var env = Environment.init(allocator, null);
    defer env.deinit();

    try env.put("x", Value{ .integer = 42 });

    var addition = try parse_to_tree(allocator, "5 + x");
    defer addition.deinit(allocator);

    const result = try evaluate(allocator, &addition.root, &env);
    std.debug.print("Result: {any}\n", .{result});
    try std.testing.expectEqual(Value{ .integer = 47 }, result);
}

test "evaluate integer and float operations" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Integer addition
    var tree1 = try parse_to_tree(allocator, "42 + 5");
    defer tree1.deinit(allocator);
    var result = try evaluate(allocator, &tree1.root, &env);
    try std.testing.expectEqual(Value{ .integer = 47 }, result);

    // Mixed integer and float
    var tree2 = try parse_to_tree(allocator, "42 + 3.14");
    defer tree2.deinit(allocator);
    result = try evaluate(allocator, &tree2.root, &env);
    try std.testing.expectEqual(Value{ .float = 45.14 }, result);

    // integer division
    var tree3 = try parse_to_tree(allocator, "10 / 3");
    defer tree3.deinit(allocator);
    result = try evaluate(allocator, &tree3.root, &env);
    try std.testing.expectEqual(Value{ .integer = 3 }, result);

    // float division
    var tree4 = try parse_to_tree(allocator, "1e5 + -.123e-2");
    defer tree4.deinit(allocator);
    result = try evaluate(allocator, &tree4.root, &env);
    try std.testing.expectEqual(Value{ .float = 99999.99877 }, result);
}

test "evaluate literals" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Integer literal
    var tree_int = try parse_to_tree(allocator, "42");
    defer tree_int.deinit(allocator);
    var result = try evaluate(allocator, &tree_int.root, &env);
    try std.testing.expectEqual(Value{ .integer = 42 }, result);

    // Float literal
    var tree_float = try parse_to_tree(allocator, "3.14");
    defer tree_float.deinit(allocator);
    result = try evaluate(allocator, &tree_float.root, &env);
    try std.testing.expectEqual(Value{ .float = 3.14 }, result);

    // String literal
    var tree_str = try parse_to_tree(allocator, "'hello'");
    defer tree_str.deinit(allocator);
    result = try evaluate(allocator, &tree_str.root, &env);
    try std.testing.expectEqualStrings("hello", result.string);

    // Date literal
    var tree_date = try parse_to_tree(allocator, "d'2023-01-01'");
    defer tree_date.deinit(allocator);
    result = try evaluate(allocator, &tree_date.root, &env);
    try std.testing.expectEqualStrings("2023-01-01", result.date);

    // List literal
    var tree_list = try parse_to_tree(allocator, "[1, 2, 3]");
    defer tree_list.deinit(allocator);
    var list_result = try evaluate(allocator, &tree_list.root, &env);
    defer deinitValue(allocator, list_result);
    try std.testing.expectEqual(@as(usize, 3), list_result.list.len);
    try std.testing.expectEqual(Value{ .integer = 1 }, list_result.list[0]);
    try std.testing.expectEqual(Value{ .integer = 2 }, list_result.list[1]);
    try std.testing.expectEqual(Value{ .integer = 3 }, list_result.list[2]);
}

test "evaluate arithmetic operators" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Addition
    var tree_add = try parse_to_tree(allocator, "2 + 3");
    defer tree_add.deinit(allocator);
    var result = try evaluate(allocator, &tree_add.root, &env);
    try std.testing.expectEqual(Value{ .integer = 5 }, result);

    // Subtraction
    var tree_sub = try parse_to_tree(allocator, "5 - 3");
    defer tree_sub.deinit(allocator);
    result = try evaluate(allocator, &tree_sub.root, &env);
    try std.testing.expectEqual(Value{ .integer = 2 }, result);

    // Multiplication
    var tree_mul = try parse_to_tree(allocator, "4 * 3");
    defer tree_mul.deinit(allocator);
    result = try evaluate(allocator, &tree_mul.root, &env);
    try std.testing.expectEqual(Value{ .integer = 12 }, result);

    // Integer division
    var tree_div_int = try parse_to_tree(allocator, "7 / 2");
    defer tree_div_int.deinit(allocator);
    result = try evaluate(allocator, &tree_div_int.root, &env);
    try std.testing.expectEqual(Value{ .integer = 3 }, result);

    // Float division
    var tree_div_float = try parse_to_tree(allocator, "7.0 / 2");
    defer tree_div_float.deinit(allocator);
    result = try evaluate(allocator, &tree_div_float.root, &env);
    try std.testing.expectEqual(Value{ .float = 3.5 }, result);

    // Complex expression
    var tree_complex = try parse_to_tree(allocator, "2 * (3 + 4) - 5");
    defer tree_complex.deinit(allocator);
    result = try evaluate(allocator, &tree_complex.root, &env);
    try std.testing.expectEqual(Value{ .integer = 9 }, result);
}

test "evaluate comparison operators" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Greater than
    var tree_gt = try parse_to_tree(allocator, "5 > 3");
    defer tree_gt.deinit(allocator);
    var result = try evaluate(allocator, &tree_gt.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    // Less than
    var tree_lt = try parse_to_tree(allocator, "5 < 3");
    defer tree_lt.deinit(allocator);
    result = try evaluate(allocator, &tree_lt.root, &env);
    try std.testing.expectEqual(Value{ .boolean = false }, result);

    // Equal to
    var tree_eq = try parse_to_tree(allocator, "5 == 5");
    defer tree_eq.deinit(allocator);
    result = try evaluate(allocator, &tree_eq.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    // Not equal to
    var tree_neq = try parse_to_tree(allocator, "5 != 3");
    defer tree_neq.deinit(allocator);
    result = try evaluate(allocator, &tree_neq.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    // String comparison
    var tree_str_cmp = try parse_to_tree(allocator, "'abc' < 'def'");
    defer tree_str_cmp.deinit(allocator);
    result = try evaluate(allocator, &tree_str_cmp.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    // Date comparison
    var tree_date_cmp = try parse_to_tree(allocator, "d'2023-01-01' < d'2023-12-31'");
    defer tree_date_cmp.deinit(allocator);
    result = try evaluate(allocator, &tree_date_cmp.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);
}

test "evaluate boolean operators" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    var tree = try parse_to_tree(allocator, "(5 < 3)");
    defer tree.deinit(allocator);
    var result = try evaluate(allocator, &tree.root, &env);
    try std.testing.expectEqual(Value{ .boolean = false }, result);

    // AND
    var tree_and = try parse_to_tree(allocator, "(5 > 3) and (2 < 4)");
    defer tree_and.deinit(allocator);
    result = try evaluate(allocator, &tree_and.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    // OR
    var tree_or = try parse_to_tree(allocator, "(5 < 3) or (2 < 4)");
    defer tree_or.deinit(allocator);
    result = try evaluate(allocator, &tree_or.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    // NOT
    var tree_not = try parse_to_tree(allocator, "!(5 < 3)");
    defer tree_not.deinit(allocator);
    result = try evaluate(allocator, &tree_not.root, &env);
    std.debug.print("result: {any}\n", .{result});
    try std.testing.expectEqual(Value{ .boolean = true }, result);

    // Complex boolean expression
    var tree_complex = try parse_to_tree(allocator, "(5 > 3 and 2 < 4) or not(1 == 1)");
    defer tree_complex.deinit(allocator);
    result = try evaluate(allocator, &tree_complex.root, &env);
    try std.testing.expectEqual(Value{ .boolean = true }, result);
}

test "evaluate environment variables" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Set up environment
    try env.put("x", Value{ .integer = 42 });
    try env.put("y", Value{ .float = 3.14 });
    try env.put("name", Value{ .string = "test" });

    // Test variable access
    var tree_var_access = try parse_to_tree(allocator, "x + 5");
    defer tree_var_access.deinit(allocator);
    var result = try evaluate(allocator, &tree_var_access.root, &env);
    try std.testing.expectEqual(Value{ .integer = 47 }, result);

    // Test mixed variable types
    var tree_mixed_var = try parse_to_tree(allocator, "x + y");
    defer tree_mixed_var.deinit(allocator);
    result = try evaluate(allocator, &tree_mixed_var.root, &env);
    try std.testing.expectEqual(Value{ .float = 45.14 }, result);

    // Test undefined variable
    var tree_undefined_var = try parse_to_tree(allocator, "z + 1");
    defer tree_undefined_var.deinit(allocator);
    try std.testing.expectError(error.UndefinedIdentifier, evaluate(allocator, &tree_undefined_var.root, &env));
}
