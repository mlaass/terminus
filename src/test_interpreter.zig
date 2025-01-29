const std = @import("std");
const Environment = @import("interpreter_environment.zig").Environment;
const Value = @import("interpreter.zig").Value;
const parse_to_tree = @import("parser.zig").parse_to_tree;
const evaluate = @import("interpreter.zig").evaluate;

test "evaluate simple expression" {
    const allocator = std.testing.allocator;

    var env = Environment.init(allocator, null);
    defer env.deinit();

    try env.put("x", Value{ .data = .{ .integer = 42 } });

    var addition = try parse_to_tree(allocator, "5 + x");
    defer addition.deinit(allocator);

    var result = try evaluate(allocator, &addition.root, &env);
    defer result.deinit();
    std.debug.print("Result: {any}\n", .{result});
    try std.testing.expectEqual(Value{ .data = .{ .integer = 47 } }, result);
}

test "evaluate integer and float operations" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Integer addition
    var tree1 = try parse_to_tree(allocator, "42 + 5");
    defer tree1.deinit(allocator);
    var result_int = try evaluate(allocator, &tree1.root, &env);
    defer result_int.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .integer = 47 } }, result_int);

    // Mixed integer and float
    var tree2 = try parse_to_tree(allocator, "42 + 3.14");
    defer tree2.deinit(allocator);
    var result_float = try evaluate(allocator, &tree2.root, &env);
    defer result_float.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .float = 45.14 } }, result_float);

    // integer division
    var tree3 = try parse_to_tree(allocator, "10 / 3");
    defer tree3.deinit(allocator);
    var result_int_div = try evaluate(allocator, &tree3.root, &env);
    defer result_int_div.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .integer = 3 } }, result_int_div);

    // float division
    var tree4 = try parse_to_tree(allocator, "1e5 + -.123e-2");
    defer tree4.deinit(allocator);
    var result_float_div = try evaluate(allocator, &tree4.root, &env);
    defer result_float_div.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .float = 99999.99877 } }, result_float_div);
}

test "evaluate literals" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Integer literal
    var tree_int = try parse_to_tree(allocator, "42");
    defer tree_int.deinit(allocator);
    var result_int = try evaluate(allocator, &tree_int.root, &env);
    defer result_int.deinit();
    try std.testing.expectEqual(.{ .integer = 42 }, result_int.data);

    // Float literal
    var tree_float = try parse_to_tree(allocator, "3.14");
    defer tree_float.deinit(allocator);
    var result_float = try evaluate(allocator, &tree_float.root, &env);
    defer result_float.deinit();
    try std.testing.expectEqual(.{ .float = 3.14 }, result_float.data);

    // String literal
    var tree_str = try parse_to_tree(allocator, "'hello'");
    defer tree_str.deinit(allocator);
    var result_str = try evaluate(allocator, &tree_str.root, &env);
    defer result_str.deinit();
    try std.testing.expectEqualStrings("hello", result_str.data.string);

    // Date literal
    var tree_date = try parse_to_tree(allocator, "d'2023-01-01'");
    defer tree_date.deinit(allocator);
    var result_date = try evaluate(allocator, &tree_date.root, &env);
    defer result_date.deinit();
    try std.testing.expectEqualStrings("2023-01-01", result_date.data.date);

    // List literal
    var tree_list = try parse_to_tree(allocator, "[1, 2, 3]");
    defer tree_list.deinit(allocator);
    var list_result = try evaluate(allocator, &tree_list.root, &env);
    defer list_result.deinit();
    try std.testing.expectEqual(@as(usize, 3), list_result.data.list.len);
    try std.testing.expectEqual(Value{ .data = .{ .integer = 1 } }, list_result.data.list[0]);
    try std.testing.expectEqual(Value{ .data = .{ .integer = 2 } }, list_result.data.list[1]);
    try std.testing.expectEqual(Value{ .data = .{ .integer = 3 } }, list_result.data.list[2]);
}

test "evaluate arithmetic operators" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Addition
    var tree_add = try parse_to_tree(allocator, "2 + 3");
    defer tree_add.deinit(allocator);
    var result_add = try evaluate(allocator, &tree_add.root, &env);
    defer result_add.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .integer = 5 } }, result_add);

    // Subtraction
    var tree_sub = try parse_to_tree(allocator, "5 - 3");
    defer tree_sub.deinit(allocator);
    var result_sub = try evaluate(allocator, &tree_sub.root, &env);
    defer result_sub.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .integer = 2 } }, result_sub);

    // Multiplication
    var tree_mul = try parse_to_tree(allocator, "4 * 3");
    defer tree_mul.deinit(allocator);
    var result_mul = try evaluate(allocator, &tree_mul.root, &env);
    defer result_mul.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .integer = 12 } }, result_mul);

    // Integer division
    var tree_div_int = try parse_to_tree(allocator, "7 / 2");
    defer tree_div_int.deinit(allocator);
    var result_div_int = try evaluate(allocator, &tree_div_int.root, &env);
    defer result_div_int.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .integer = 3 } }, result_div_int);

    // Float division
    var tree_div_float = try parse_to_tree(allocator, "7.0 / 2");
    defer tree_div_float.deinit(allocator);
    var result_div_float = try evaluate(allocator, &tree_div_float.root, &env);
    defer result_div_float.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .float = 3.5 } }, result_div_float);

    // Complex expression
    var tree_complex = try parse_to_tree(allocator, "2 * (3 + 4) - 5");
    defer tree_complex.deinit(allocator);
    var result_complex = try evaluate(allocator, &tree_complex.root, &env);
    defer result_complex.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .integer = 9 } }, result_complex);
}

test "evaluate comparison operators" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Greater than
    var tree_gt = try parse_to_tree(allocator, "5 > 3");
    defer tree_gt.deinit(allocator);
    var result_gt = try evaluate(allocator, &tree_gt.root, &env);
    defer result_gt.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_gt);

    // Less than
    var tree_lt = try parse_to_tree(allocator, "5 < 3");
    defer tree_lt.deinit(allocator);
    var result_lt = try evaluate(allocator, &tree_lt.root, &env);
    defer result_lt.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = false } }, result_lt);

    // Equal to
    var tree_eq = try parse_to_tree(allocator, "5 == 5");
    defer tree_eq.deinit(allocator);
    var result_eq = try evaluate(allocator, &tree_eq.root, &env);
    defer result_eq.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_eq);

    // Not equal to
    var tree_neq = try parse_to_tree(allocator, "5 != 3");
    defer tree_neq.deinit(allocator);
    var result_neq = try evaluate(allocator, &tree_neq.root, &env);
    defer result_neq.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_neq);

    // String comparison
    var tree_str_cmp = try parse_to_tree(allocator, "'abc' < 'def'");
    defer tree_str_cmp.deinit(allocator);
    var result_str_cmp = try evaluate(allocator, &tree_str_cmp.root, &env);
    defer result_str_cmp.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_str_cmp);

    // Date comparison
    var tree_date_cmp = try parse_to_tree(allocator, "d'2023-01-01' < d'2023-12-31'");
    defer tree_date_cmp.deinit(allocator);
    var result_date_cmp = try evaluate(allocator, &tree_date_cmp.root, &env);
    defer result_date_cmp.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_date_cmp);
}

test "evaluate boolean operators" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    var tree = try parse_to_tree(allocator, "(5 < 3)");
    defer tree.deinit(allocator);
    var result = try evaluate(allocator, &tree.root, &env);
    defer result.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = false } }, result);

    // AND
    var tree_and = try parse_to_tree(allocator, "(5 > 3) and (2 < 4)");
    defer tree_and.deinit(allocator);
    var result_and = try evaluate(allocator, &tree_and.root, &env);
    defer result_and.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_and);

    // OR
    var tree_or = try parse_to_tree(allocator, "(5 < 3) or (2 < 4)");
    defer tree_or.deinit(allocator);
    var result_or = try evaluate(allocator, &tree_or.root, &env);
    defer result_or.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_or);

    // NOT
    var tree_not = try parse_to_tree(allocator, "not(5 < 3)");
    defer tree_not.deinit(allocator);
    var result_not = try evaluate(allocator, &tree_not.root, &env);
    defer result_not.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_not);

    // NOT
    var tree_not2 = try parse_to_tree(allocator, "!(5 < 3)");
    defer tree_not2.deinit(allocator);
    var result_not2 = try evaluate(allocator, &tree_not2.root, &env);
    defer result_not2.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_not2);

    // Complex boolean expression
    var tree_complex = try parse_to_tree(allocator, "(5 > 3 and 2 < 4) or not(1 == 1)");
    defer tree_complex.deinit(allocator);
    var result_complex = try evaluate(allocator, &tree_complex.root, &env);
    defer result_complex.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .boolean = true } }, result_complex);
}

test "evaluate environment variables" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Set up environment
    try env.put("x", Value{ .data = .{ .integer = 42 } });
    try env.put("y", Value{ .data = .{ .float = 3.14 } });
    try env.put("name", Value{ .data = .{ .string = "test" } });

    // Test variable access
    var tree_var_access = try parse_to_tree(allocator, "x + 5");
    defer tree_var_access.deinit(allocator);
    var result = try evaluate(allocator, &tree_var_access.root, &env);
    defer result.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .integer = 47 } }, result);

    // Test mixed variable types
    var tree_mixed_var = try parse_to_tree(allocator, "x + y");
    defer tree_mixed_var.deinit(allocator);
    var result_mixed_var = try evaluate(allocator, &tree_mixed_var.root, &env);
    defer result_mixed_var.deinit();
    try std.testing.expectEqual(Value{ .data = .{ .float = 45.14 } }, result_mixed_var);

    // Test undefined variable
    var tree_undefined_var = try parse_to_tree(allocator, "z + 1");
    defer tree_undefined_var.deinit(allocator);
    try std.testing.expectError(error.UndefinedIdentifier, evaluate(allocator, &tree_undefined_var.root, &env));
}
