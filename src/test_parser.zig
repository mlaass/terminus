const std = @import("std");
const Node = @import("term_parser.zig").Node;
const NodeType = @import("term_parser.zig").NodeType;
const TokenType = @import("term_parser.zig").TokenType;
const Token = @import("term_parser.zig").Token;
const tokenize = @import("term_parser.zig").tokenize;
const shunting_yard = @import("term_parser.zig").shunting_yard;
const parse_to_tree = @import("term_parser.zig").parse_to_tree;

test "tokenize simple case" {
    const allocator = std.testing.allocator;

    const result = try tokenize(allocator, "tm1 and tm2");
    defer {
        for (result) |token| {
            allocator.free(token.value);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("tm1", result[0].value);
    try std.testing.expectEqual(TokenType.identifier, result[0].type);
    try std.testing.expectEqualStrings("and", result[1].value);
    try std.testing.expectEqual(TokenType.operator, result[1].type);
    try std.testing.expectEqualStrings("tm2", result[2].value);
    try std.testing.expectEqual(TokenType.identifier, result[2].type);
}

// Add a test for date string tokenization
test "tokenize date string" {
    const allocator = std.testing.allocator;

    const result = try tokenize(allocator, "d'2023-01-01' and tm2");
    defer {
        for (result) |token| {
            allocator.free(token.value);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("d'2023-01-01'", result[0].value);
    try std.testing.expectEqual(TokenType.date_string, result[0].type);
    try std.testing.expectEqualStrings("and", result[1].value);
    try std.testing.expectEqual(TokenType.operator, result[1].type);
    try std.testing.expectEqualStrings("tm2", result[2].value);
    try std.testing.expectEqual(TokenType.identifier, result[2].type);
}

test "shunting yard simple expression" {
    const allocator = std.testing.allocator;

    const tokens = try tokenize(allocator, "3 + 4");
    defer {
        for (tokens) |token| {
            allocator.free(token.value);
        }
        allocator.free(tokens);
    }

    const result = try shunting_yard(allocator, tokens);
    defer {
        for (result) |*node| {
            node.deinit(allocator);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(NodeType.literal_integer, result[0].type);
    try std.testing.expectEqual(NodeType.literal_integer, result[1].type);
    try std.testing.expectEqual(NodeType.binary_operator, result[2].type);
    try std.testing.expectEqual(@as(i64, 3), result[0].value.integer);
    try std.testing.expectEqual(@as(i64, 4), result[1].value.integer);
    try std.testing.expectEqualStrings("+", result[2].value.operator);
}

test "parse simple arithmetic expression" {
    const allocator = std.testing.allocator;

    var tree = try parse_to_tree(allocator, "3 + 4");
    defer tree.deinit(allocator);

    try std.testing.expectEqual(NodeType.binary_operator, tree.root.type);
    try std.testing.expectEqualStrings("+", tree.root.value.operator);

    const args = tree.root.args.?;
    try std.testing.expectEqual(NodeType.literal_integer, args[0].type);
    try std.testing.expectEqual(@as(i64, 3), args[0].value.integer);
    try std.testing.expectEqual(NodeType.literal_integer, args[1].type);
    try std.testing.expectEqual(@as(i64, 4), args[1].value.integer);
}

test "parse function call" {
    const allocator = std.testing.allocator;

    var tree = try parse_to_tree(allocator, "add(1, 2)");
    defer tree.deinit(allocator);

    try std.testing.expectEqual(NodeType.function, tree.root.type);
    try std.testing.expectEqualStrings("add", tree.root.value.function.name);
    try std.testing.expectEqual(@as(usize, 2), tree.root.value.function.arg_count);

    const args = tree.root.args.?;
    try std.testing.expectEqual(NodeType.literal_integer, args[0].type);
    try std.testing.expectEqual(@as(i64, 1), args[0].value.integer);
    try std.testing.expectEqual(NodeType.literal_integer, args[1].type);
    try std.testing.expectEqual(@as(i64, 2), args[1].value.integer);
}

test "parse complex expression" {
    const allocator = std.testing.allocator;

    var tree = try parse_to_tree(allocator, "add(1 + 2, mul(3, 4))");
    defer tree.deinit(allocator);

    try std.testing.expectEqual(NodeType.function, tree.root.type);
    try std.testing.expectEqualStrings("add", tree.root.value.function.name);

    const args = tree.root.args.?;
    try std.testing.expectEqual(NodeType.binary_operator, args[0].type);
    try std.testing.expectEqual(NodeType.function, args[1].type);

    const add_args = args[0].args.?;
    try std.testing.expectEqual(@as(i64, 1), add_args[0].value.integer);
    try std.testing.expectEqual(@as(i64, 2), add_args[1].value.integer);

    const mul_args = args[1].args.?;
    try std.testing.expectEqual(@as(i64, 3), mul_args[0].value.integer);
    try std.testing.expectEqual(@as(i64, 4), mul_args[1].value.integer);
}

test "parse list expression" {
    const allocator = std.testing.allocator;

    var tree = try parse_to_tree(allocator, "[1, 2, 3]");
    defer tree.deinit(allocator);

    try std.testing.expectEqual(NodeType.list, tree.root.type);
    try std.testing.expectEqual(@as(usize, 3), tree.root.value.list.element_count);

    const elements = tree.root.args.?;
    try std.testing.expectEqual(@as(i64, 1), elements[0].value.integer);
    try std.testing.expectEqual(@as(i64, 2), elements[1].value.integer);
    try std.testing.expectEqual(@as(i64, 3), elements[2].value.integer);
}

test "tokenize all node types" {
    const allocator = std.testing.allocator;

    // Test all types in one complex expression
    const result = try tokenize(allocator, "add($func(3.14, -42), d'2023-01-01', 'string', [1, 2]) > 5 and not true");
    defer {
        for (result) |token| {
            allocator.free(token.value);
        }
        allocator.free(result);
    }
    std.debug.print("tokens:\n", .{});
    // var i: u64 = 0;
    // for (result) |token| {
    //     std.debug.print("{}. \"{s}\" ({s})\n", .{ (i + 1), token.value, @tagName(token.type) });
    //     i += 1;
    // }
    // Expected tokens in order:
    // 1. "add" (identifier)
    // 2. "(" (left_paren)
    // 3. "$func" (identifier)
    // 4. "(" (left_paren)
    // 5. "3.14" (number)
    // 6. "," (comma)
    // 7. "-42" (number)
    // 8. ")" (right_paren)
    // 9. "," (comma)
    // 10. "d'2023-01-01'" (date_string)
    // 11. "," (comma)
    // 12. "'string'" (string)
    // 13. "," (comma)
    // 14. "[" (left_bracket)
    // 15. "1" (number)
    // 16. "," (comma)
    // 17. "2" (number)
    // 18. "]" (right_bracket)
    // 19. ")" (right_paren)
    // 20. ">" (operator)
    // 21. "5" (number)
    // 22. "and" (operator)
    // 23. "not" (operator)
    // 24. "true" (identifier)

    try std.testing.expectEqual(@as(usize, 24), result.len);

    // Test specific tokens
    try std.testing.expectEqual(TokenType.identifier, result[0].type);
    try std.testing.expectEqualStrings("add", result[0].value);

    try std.testing.expectEqual(TokenType.left_paren, result[1].type);
    try std.testing.expectEqualStrings("(", result[1].value);

    try std.testing.expectEqual(TokenType.identifier, result[2].type);
    try std.testing.expectEqualStrings("$func", result[2].value);

    try std.testing.expectEqual(TokenType.number, result[4].type);
    try std.testing.expectEqualStrings("3.14", result[4].value);

    try std.testing.expectEqual(TokenType.number, result[6].type);
    try std.testing.expectEqualStrings("-42", result[6].value);

    try std.testing.expectEqual(TokenType.date_string, result[9].type);
    try std.testing.expectEqualStrings("d'2023-01-01'", result[9].value);

    try std.testing.expectEqual(TokenType.string, result[11].type);
    try std.testing.expectEqualStrings("'string'", result[11].value);

    try std.testing.expectEqual(TokenType.left_bracket, result[13].type);
    try std.testing.expectEqualStrings("[", result[13].value);

    try std.testing.expectEqual(TokenType.operator, result[19].type);
    try std.testing.expectEqualStrings(">", result[19].value);

    try std.testing.expectEqual(TokenType.operator, result[21].type);
    try std.testing.expectEqualStrings("and", result[21].value);

    try std.testing.expectEqual(TokenType.operator, result[22].type);
    try std.testing.expectEqualStrings("not", result[22].value);

    try std.testing.expectEqual(TokenType.identifier, result[23].type);
    try std.testing.expectEqualStrings("true", result[23].value);
}

test "tokenize list expressions" {
    const allocator = std.testing.allocator;

    const result = try tokenize(allocator, "[1, 2, 3]");
    defer {
        for (result) |token| {
            allocator.free(token.value);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 7), result.len);
    try std.testing.expectEqual(TokenType.left_bracket, result[0].type);
    try std.testing.expectEqualStrings("[", result[0].value);
    try std.testing.expectEqual(TokenType.number, result[1].type);
    try std.testing.expectEqualStrings("1", result[1].value);
    try std.testing.expectEqual(TokenType.comma, result[2].type);
    try std.testing.expectEqualStrings(",", result[2].value);
    try std.testing.expectEqual(TokenType.number, result[3].type);
    try std.testing.expectEqualStrings("2", result[3].value);
    try std.testing.expectEqual(TokenType.comma, result[4].type);
    try std.testing.expectEqualStrings(",", result[4].value);
    try std.testing.expectEqual(TokenType.number, result[5].type);
    try std.testing.expectEqualStrings("3", result[5].value);
    try std.testing.expectEqual(TokenType.right_bracket, result[6].type);
    try std.testing.expectEqualStrings("]", result[6].value);
}

test "tokenize function calls" {
    const allocator = std.testing.allocator;

    const result = try tokenize(allocator, "add(1, 2)");
    defer {
        for (result) |token| {
            allocator.free(token.value);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 6), result.len);
    try std.testing.expectEqual(TokenType.identifier, result[0].type);
    try std.testing.expectEqualStrings("add", result[0].value);
    try std.testing.expectEqual(TokenType.left_paren, result[1].type);
    try std.testing.expectEqualStrings("(", result[1].value);
    try std.testing.expectEqual(TokenType.number, result[2].type);
    try std.testing.expectEqualStrings("1", result[2].value);
    try std.testing.expectEqual(TokenType.comma, result[3].type);
    try std.testing.expectEqualStrings(",", result[3].value);
    try std.testing.expectEqual(TokenType.number, result[4].type);
    try std.testing.expectEqualStrings("2", result[4].value);
    try std.testing.expectEqual(TokenType.right_paren, result[5].type);
    try std.testing.expectEqualStrings(")", result[5].value);
}

test "tokenize nested expressions" {
    const allocator = std.testing.allocator;

    const result = try tokenize(allocator, "add(1 + 2, mul(3, 4))");
    defer {
        for (result) |token| {
            allocator.free(token.value);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 13), result.len);
    try std.testing.expectEqual(TokenType.identifier, result[0].type);
    try std.testing.expectEqualStrings("add", result[0].value);
    try std.testing.expectEqual(TokenType.left_paren, result[1].type);
    try std.testing.expectEqual(TokenType.number, result[2].type);
    try std.testing.expectEqual(TokenType.operator, result[3].type);
    try std.testing.expectEqualStrings("+", result[3].value);
    try std.testing.expectEqual(TokenType.number, result[4].type);
    try std.testing.expectEqual(TokenType.comma, result[5].type);
    try std.testing.expectEqual(TokenType.identifier, result[6].type);
    try std.testing.expectEqualStrings("mul", result[6].value);
    try std.testing.expectEqual(TokenType.left_paren, result[7].type);
    try std.testing.expectEqual(TokenType.number, result[8].type);
    try std.testing.expectEqual(TokenType.comma, result[9].type);
    try std.testing.expectEqual(TokenType.number, result[10].type);
    try std.testing.expectEqual(TokenType.right_paren, result[11].type);
}

// test "debug list parsing" {
//     const allocator = std.testing.allocator;
//     const expression = "[1, 2, 3]";

//     // First check tokenization
//     const tokens = try tokenize(allocator, expression);
//     defer {
//         for (tokens) |token| {
//             allocator.free(token.value);
//         }
//         allocator.free(tokens);
//     }

//     std.debug.print("\nTokens for '{s}':\n", .{expression});
//     for (tokens, 0..) |token, i| {
//         std.debug.print("  {d}: {s} ({s})\n", .{ i, @tagName(token.type), token.value });
//     }

//     // Then check RPN nodes
//     const rpn = try shunting_yard(allocator, tokens);
//     defer {
//         for (rpn) |*node| {
//             node.deinit(allocator);
//         }
//         allocator.free(rpn);
//     }

//     std.debug.print("\nRPN nodes:\n", .{});
//     for (rpn, 0..) |node, i| {
//         std.debug.print("  {d}: {s}", .{ i, @tagName(node.type) });
//         switch (node.type) {
//             .literal => std.debug.print(" ({d})", .{node.value.literal}),
//             .list => std.debug.print(" (elements: {d})", .{node.value.list.element_count}),
//             else => {},
//         }
//         std.debug.print("\n", .{});
//     }
// }

// test "debug function parsing" {
//     const allocator = std.testing.allocator;
//     const expression = "add(1, 2)";

//     // First check tokenization
//     const tokens = try tokenize(allocator, expression);
//     defer {
//         for (tokens) |token| {
//             allocator.free(token.value);
//         }
//         allocator.free(tokens);
//     }

//     std.debug.print("\nTokens for '{s}':\n", .{expression});
//     for (tokens, 0..) |token, i| {
//         std.debug.print("  {d}: {s} ({s})\n", .{ i, @tagName(token.type), token.value });
//     }

//     // Then check RPN nodes
//     const rpn = try shunting_yard(allocator, tokens);
//     defer {
//         for (rpn) |*node| {
//             node.deinit(allocator);
//         }
//         allocator.free(rpn);
//     }

//     std.debug.print("\nRPN nodes:\n", .{});
//     for (rpn, 0..) |node, i| {
//         std.debug.print("  {d}: {s}", .{ i, @tagName(node.type) });
//         switch (node.type) {
//             .literal => std.debug.print(" ({d})", .{node.value.literal}),
//             .function => std.debug.print(" ({s}, args: {d})", .{ node.value.function.name, node.value.function.arg_count }),
//             else => {},
//         }
//         std.debug.print("\n", .{});
//     }
// }

test "shunting yard function call" {
    const allocator = std.testing.allocator;

    const tokens = try tokenize(allocator, "add(1, 2)");
    defer {
        for (tokens) |token| {
            allocator.free(token.value);
        }
        allocator.free(tokens);
    }

    const result = try shunting_yard(allocator, tokens);
    defer {
        for (result) |*node| {
            node.deinit(allocator);
        }
        allocator.free(result);
    }

    // Expected RPN: 1 2 add(2)
    try std.testing.expectEqual(@as(usize, 3), result.len);

    // First two nodes should be literals
    try std.testing.expectEqual(NodeType.literal_integer, result[0].type);
    try std.testing.expectEqual(@as(i64, 1), result[0].value.integer);

    try std.testing.expectEqual(NodeType.literal_integer, result[1].type);
    try std.testing.expectEqual(@as(i64, 2), result[1].value.integer);

    // Last node should be the function
    try std.testing.expectEqual(NodeType.function, result[2].type);
    try std.testing.expectEqualStrings("add", result[2].value.function.name);
    try std.testing.expectEqual(@as(usize, 2), result[2].value.function.arg_count);
}

test "shunting yard nested function calls" {
    const allocator = std.testing.allocator;

    const tokens = try tokenize(allocator, "add(1, mul(2, 3))");
    defer {
        for (tokens) |token| {
            allocator.free(token.value);
        }
        allocator.free(tokens);
    }

    const result = try shunting_yard(allocator, tokens);
    defer {
        for (result) |*node| {
            node.deinit(allocator);
        }
        allocator.free(result);
    }

    // Expected RPN: 1 2 3 mul(2) add(2)
    try std.testing.expectEqual(@as(usize, 5), result.len);

    // Check literals
    try std.testing.expectEqual(NodeType.literal_integer, result[0].type);
    try std.testing.expectEqual(@as(i64, 1), result[0].value.integer);

    try std.testing.expectEqual(NodeType.literal_integer, result[1].type);
    try std.testing.expectEqual(@as(i64, 2), result[1].value.integer);

    try std.testing.expectEqual(NodeType.literal_integer, result[2].type);
    try std.testing.expectEqual(@as(i64, 3), result[2].value.integer);

    // Check inner function (mul)
    try std.testing.expectEqual(NodeType.function, result[3].type);
    try std.testing.expectEqualStrings("mul", result[3].value.function.name);
    try std.testing.expectEqual(@as(usize, 2), result[3].value.function.arg_count);

    // Check outer function (add)
    try std.testing.expectEqual(NodeType.function, result[4].type);
    try std.testing.expectEqualStrings("add", result[4].value.function.name);
    try std.testing.expectEqual(@as(usize, 2), result[4].value.function.arg_count);
}

test "parse numeric literals" {
    const allocator = std.testing.allocator;

    // Test integers
    var tree = try parse_to_tree(allocator, "42");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_integer, tree.root.type);
    try std.testing.expectEqual(@as(i64, 42), tree.root.value.integer);

    // Test negative integers
    tree = try parse_to_tree(allocator, "-42");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_integer, tree.root.type);
    try std.testing.expectEqual(@as(i64, -42), tree.root.value.integer);

    // Test decimal numbers
    tree = try parse_to_tree(allocator, "3.14");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_float, tree.root.type);
    try std.testing.expectEqual(@as(f64, 3.14), tree.root.value.float);

    // Test leading decimal point
    tree = try parse_to_tree(allocator, ".5");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_float, tree.root.type);
    try std.testing.expectEqual(@as(f64, 0.5), tree.root.value.float);

    // Test negative decimal numbers
    tree = try parse_to_tree(allocator, "-3.14");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_float, tree.root.type);
    try std.testing.expectEqual(@as(f64, -3.14), tree.root.value.float);

    // Test scientific notation
    tree = try parse_to_tree(allocator, "1e5");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_float, tree.root.type);
    try std.testing.expectEqual(@as(f64, 100000.0), tree.root.value.float);

    // Test scientific notation with decimal
    tree = try parse_to_tree(allocator, "1.23e4");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_float, tree.root.type);
    try std.testing.expectEqual(@as(f64, 12300.0), tree.root.value.float);

    // Test negative exponents
    tree = try parse_to_tree(allocator, "1e-5");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_float, tree.root.type);
    try std.testing.expectEqual(@as(f64, 0.00001), tree.root.value.float);

    // Test explicit positive exponents
    tree = try parse_to_tree(allocator, "1.23e+4");
    defer tree.deinit(allocator);
    try std.testing.expectEqual(NodeType.literal_float, tree.root.type);
    try std.testing.expectEqual(@as(f64, 12300.0), tree.root.value.float);
}

test "tokenize number formats" {
    const allocator = std.testing.allocator;

    // Test cases with expected type and value
    const TestCase = struct {
        input: []const u8,
        expected_value: []const u8,
    };

    const test_cases = [_]TestCase{
        // Integers
        .{ .input = "42", .expected_value = "42" },
        .{ .input = "-42", .expected_value = "-42" },
        // Decimal numbers
        .{ .input = "3.14", .expected_value = "3.14" },
        .{ .input = "-3.14", .expected_value = "-3.14" },
        // Leading decimal point
        .{ .input = ".5", .expected_value = ".5" },
        .{ .input = "-.5", .expected_value = "-.5" },
        // Scientific notation
        .{ .input = "1e5", .expected_value = "1e5" },
        .{ .input = "1.23e4", .expected_value = "1.23e4" },
        .{ .input = "1e-5", .expected_value = "1e-5" },
        .{ .input = "-1.23e-4", .expected_value = "-1.23e-4" },
        .{ .input = "1.23e+4", .expected_value = "1.23e+4" },
        .{ .input = "-.23e+4", .expected_value = "-.23e+4" },
    };

    for (test_cases) |tc| {
        const result = try tokenize(allocator, tc.input);
        defer {
            for (result) |token| {
                allocator.free(token.value);
            }
            allocator.free(result);
        }

        try std.testing.expectEqual(@as(usize, 1), result.len);
        try std.testing.expectEqual(TokenType.number, result[0].type);
        try std.testing.expectEqualStrings(tc.expected_value, result[0].value);

        std.debug.print("Tokenized '{s}' -> '{s}'\n", .{ tc.input, result[0].value });
    }
}

test "tokenize number in expressions" {
    const allocator = std.testing.allocator;

    const test_cases = [_][]const u8{
        "1 + .5",
        "-1.23e-4 * 3",
        "func(.5, -2)",
        "1e5 + .123e-2",
    };

    for (test_cases) |expr| {
        const result = try tokenize(allocator, expr);
        defer {
            for (result) |token| {
                allocator.free(token.value);
            }
            allocator.free(result);
        }

        std.debug.print("\nTokenizing '{s}':\n", .{expr});
        for (result) |token| {
            std.debug.print("  {s}: '{s}'\n", .{ @tagName(token.type), token.value });
        }
    }
}

test "shunting yard operator precedence" {
    const allocator = std.testing.allocator;

    // Test arithmetic precedence (* before +)
    {
        const tokens = try tokenize(allocator, "2 + 3 * 4");
        defer {
            for (tokens) |token| {
                allocator.free(token.value);
            }
            allocator.free(tokens);
        }

        const result = try shunting_yard(allocator, tokens);
        defer {
            for (result) |*node| {
                node.deinit(allocator);
            }
            allocator.free(result);
        }

        // Expected RPN: 2 3 4 * +
        try std.testing.expectEqual(@as(usize, 5), result.len);
        try std.testing.expectEqual(NodeType.literal_integer, result[0].type);
        try std.testing.expectEqual(@as(i64, 2), result[0].value.integer);
        try std.testing.expectEqual(NodeType.literal_integer, result[1].type);
        try std.testing.expectEqual(@as(i64, 3), result[1].value.integer);
        try std.testing.expectEqual(NodeType.literal_integer, result[2].type);
        try std.testing.expectEqual(@as(i64, 4), result[2].value.integer);
        try std.testing.expectEqual(NodeType.binary_operator, result[3].type);
        try std.testing.expectEqualStrings("*", result[3].value.operator);
        try std.testing.expectEqual(NodeType.binary_operator, result[4].type);
        try std.testing.expectEqualStrings("+", result[4].value.operator);
    }

    // Test logical precedence (and before or)
    {
        const tokens = try tokenize(allocator, "a or b and c");
        defer {
            for (tokens) |token| {
                allocator.free(token.value);
            }
            allocator.free(tokens);
        }

        const result = try shunting_yard(allocator, tokens);
        defer {
            for (result) |*node| {
                node.deinit(allocator);
            }
            allocator.free(result);
        }

        // Expected RPN: a b c and or
        try std.testing.expectEqual(@as(usize, 5), result.len);
        try std.testing.expectEqual(NodeType.identifier, result[0].type);
        try std.testing.expectEqualStrings("a", result[0].value.identifier);
        try std.testing.expectEqual(NodeType.identifier, result[1].type);
        try std.testing.expectEqualStrings("b", result[1].value.identifier);
        try std.testing.expectEqual(NodeType.identifier, result[2].type);
        try std.testing.expectEqualStrings("c", result[2].value.identifier);
        try std.testing.expectEqual(NodeType.binary_operator, result[3].type);
        try std.testing.expectEqualStrings("and", result[3].value.operator);
        try std.testing.expectEqual(NodeType.binary_operator, result[4].type);
        try std.testing.expectEqualStrings("or", result[4].value.operator);

        std.debug.print("\nRPN for 'a or b and c':\n", .{});
        for (result) |node| {
            switch (node.type) {
                .identifier => std.debug.print("  id: {s}\n", .{node.value.identifier}),
                .binary_operator => std.debug.print("  op: {s}\n", .{node.value.operator}),
                else => std.debug.print("  other: {any}\n", .{node.type}),
            }
        }
    }

    // Test complex expression with parentheses
    {
        const tokens = try tokenize(allocator, "(a or b) and c");
        defer {
            for (tokens) |token| {
                allocator.free(token.value);
            }
            allocator.free(tokens);
        }

        const result = try shunting_yard(allocator, tokens);
        defer {
            for (result) |*node| {
                node.deinit(allocator);
            }
            allocator.free(result);
        }

        // Expected RPN: a b or c and
        try std.testing.expectEqual(@as(usize, 5), result.len);
        try std.testing.expectEqual(NodeType.identifier, result[0].type);
        try std.testing.expectEqualStrings("a", result[0].value.identifier);
        try std.testing.expectEqual(NodeType.identifier, result[1].type);
        try std.testing.expectEqualStrings("b", result[1].value.identifier);
        try std.testing.expectEqual(NodeType.binary_operator, result[2].type);
        try std.testing.expectEqualStrings("or", result[2].value.operator);
        try std.testing.expectEqual(NodeType.identifier, result[3].type);
        try std.testing.expectEqualStrings("c", result[3].value.identifier);
        try std.testing.expectEqual(NodeType.binary_operator, result[4].type);
        try std.testing.expectEqualStrings("and", result[4].value.operator);

        std.debug.print("\nRPN for '(a or b) and c':\n", .{});
        for (result) |node| {
            switch (node.type) {
                .identifier => std.debug.print("  id: {s}\n", .{node.value.identifier}),
                .binary_operator => std.debug.print("  op: {s}\n", .{node.value.operator}),
                else => std.debug.print("  other: {any}\n", .{node.type}),
            }
        }
    }

    // Test complex arithmetic expression (from failing test)
    {
        const tokens = try tokenize(allocator, "2 * (3 + 4) - 5");
        defer {
            for (tokens) |token| {
                allocator.free(token.value);
            }
            allocator.free(tokens);
        }

        const result = try shunting_yard(allocator, tokens);
        defer {
            for (result) |*node| {
                node.deinit(allocator);
            }
            allocator.free(result);
        }

        std.debug.print("\nRPN for '2 * (3 + 4) - 5':\n", .{});
        for (result) |node| {
            switch (node.type) {
                .literal_integer => std.debug.print("  int: {d}\n", .{node.value.integer}),
                .binary_operator => std.debug.print("  op: {s}\n", .{node.value.operator}),
                else => std.debug.print("  other: {any}\n", .{node.type}),
            }
        }
        // Expected RPN: 2 3 4 + * 5 -
        try std.testing.expectEqual(@as(usize, 7), result.len);
        try std.testing.expectEqual(NodeType.literal_integer, result[0].type);
        try std.testing.expectEqual(@as(i64, 2), result[0].value.integer);
        try std.testing.expectEqual(NodeType.literal_integer, result[1].type);
        try std.testing.expectEqual(@as(i64, 3), result[1].value.integer);
        try std.testing.expectEqual(NodeType.literal_integer, result[2].type);
        try std.testing.expectEqual(@as(i64, 4), result[2].value.integer);
        try std.testing.expectEqual(NodeType.binary_operator, result[3].type);
        try std.testing.expectEqualStrings("+", result[3].value.operator);
        try std.testing.expectEqual(NodeType.binary_operator, result[4].type);
        try std.testing.expectEqualStrings("*", result[4].value.operator);
        try std.testing.expectEqual(NodeType.literal_integer, result[5].type);
        try std.testing.expectEqual(@as(i64, 5), result[5].value.integer);
        try std.testing.expectEqual(NodeType.binary_operator, result[6].type);
        try std.testing.expectEqualStrings("-", result[6].value.operator);
    }

    // Test complex boolean expression (from failing test)
    {
        const tokens = try tokenize(allocator, "(5 > 3 and 2 < 4) or not(1 == 1)");
        defer {
            for (tokens) |token| {
                allocator.free(token.value);
            }
            allocator.free(tokens);
        }

        const result = try shunting_yard(allocator, tokens);
        defer {
            for (result) |*node| {
                node.deinit(allocator);
            }
            allocator.free(result);
        }

        // Expected RPN: 5 3 > 2 4 < and 1 1 == not or
        std.debug.print("\nRPN for '(5 > 3 and 2 < 4) or not(1 == 1)':\n", .{});
        for (result) |node| {
            switch (node.type) {
                .literal_integer => std.debug.print("  int: {d}\n", .{node.value.integer}),
                .binary_operator => std.debug.print("  op: {s}\n", .{node.value.operator}),
                .unary_operator => std.debug.print("  unary: {s}\n", .{node.value.operator}),
                else => std.debug.print("  other: {any}\n", .{node.type}),
            }
        }

        // Verify the structure
        try std.testing.expectEqual(@as(usize, 12), result.len);
        // First comparison: 5 > 3
        try std.testing.expectEqual(NodeType.literal_integer, result[0].type);
        try std.testing.expectEqual(@as(i64, 5), result[0].value.integer);
        try std.testing.expectEqual(NodeType.literal_integer, result[1].type);
        try std.testing.expectEqual(@as(i64, 3), result[1].value.integer);
        try std.testing.expectEqual(NodeType.binary_operator, result[2].type);
        try std.testing.expectEqualStrings(">", result[2].value.operator);
        // Second comparison: 2 < 4
        try std.testing.expectEqual(NodeType.literal_integer, result[3].type);
        try std.testing.expectEqual(@as(i64, 2), result[3].value.integer);
        try std.testing.expectEqual(NodeType.literal_integer, result[4].type);
        try std.testing.expectEqual(@as(i64, 4), result[4].value.integer);
        try std.testing.expectEqual(NodeType.binary_operator, result[5].type);
        try std.testing.expectEqualStrings("<", result[5].value.operator);
        // AND operator
        try std.testing.expectEqual(NodeType.binary_operator, result[6].type);
        try std.testing.expectEqualStrings("and", result[6].value.operator);
        // Third comparison: 1 == 1
        try std.testing.expectEqual(NodeType.literal_integer, result[7].type);
        try std.testing.expectEqual(@as(i64, 1), result[7].value.integer);
        try std.testing.expectEqual(NodeType.literal_integer, result[8].type);
        try std.testing.expectEqual(@as(i64, 1), result[8].value.integer);
        try std.testing.expectEqual(NodeType.binary_operator, result[9].type);
        try std.testing.expectEqualStrings("==", result[9].value.operator);
        // NOT operator
        try std.testing.expectEqual(NodeType.unary_operator, result[10].type);
        try std.testing.expectEqualStrings("not", result[10].value.operator);
        // OR operator
        try std.testing.expectEqual(NodeType.binary_operator, result[11].type);
        try std.testing.expectEqualStrings("or", result[11].value.operator);
    }
}
