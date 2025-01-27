const std = @import("std");

pub const TokenType = enum {
    identifier,
    number,
    string,
    date_string,
    operator,
    left_paren,
    right_paren,
    left_bracket,
    right_bracket,
    comma,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

// Token patterns for lexical analysis
pub const patterns = struct {
    const whitespace = "\\s+";
    const operators = "=>|//|\\*\\*|==|!=|<=|>=|<<|>>|\\|{1,2}|&|\\^";
    const date_string = "d\"(?:\\\\.|[^\"\\\\])*\"|d'(?:\\\\.|[^'\\\\])*'";
    const string = "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'";
    const number = "-?(?:\\d+\\.\\d*|\\.\\d+|\\d+)(?:[eE][+-]?\\d+)?";
    const identifier = "\\$[\\w\\.]+|\\b[\\w\\.]+\\b";
    const symbol = "[+\\-*/%(),<>!=]";
};

// Binary operators and their precedence
pub const binary_operators = std.ComptimeStringMap(u8, .{
    .{ "+", 6 },
    .{ "-", 6 },
    .{ "*", 7 },
    .{ "/", 7 },
    .{ "//", 7 },
    .{ "**", 9 },
    .{ "mod", 7 },
    .{ "%", 7 },
    .{ "<", 5 },
    .{ "<=", 5 },
    .{ ">", 5 },
    .{ ">=", 5 },
    .{ "==", 4 },
    .{ "!=", 4 },
    .{ "and", 2 },
    .{ "or", 1 },
    .{ "|", 3 },
    .{ "&", 3 },
    .{ "xor", 3 },
    .{ "<<", 8 },
    .{ ">>", 8 },
});

// Unary operators
pub const unary_operators = std.ComptimeStringMap(void, .{
    .{ "not", {} },
    .{ "neg", {} },
    .{ "floor", {} },
    .{ "ceil", {} },
    .{ "abs", {} },
    .{ "int", {} },
    .{ "float", {} },
    .{ "bool", {} },
});

pub const NodeType = enum {
    literal_integer,
    literal_float,
    literal_string,
    literal_date,
    identifier,
    binary_operator,
    unary_operator,
    function,
    list,
};

pub const Node = struct {
    type: NodeType,
    value: union {
        integer: i64,
        float: f64,
        string: []const u8,
        date: []const u8,
        identifier: []const u8,
        operator: []const u8,
        function: struct {
            name: []const u8,
            arg_count: usize,
        },
        list: struct {
            element_count: usize,
        },
    },
    args: ?[]Node = null,

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        switch (self.type) {
            .literal_integer, .literal_float => {},
            .literal_string => allocator.free(self.value.string),
            .literal_date => allocator.free(self.value.date),
            .identifier => allocator.free(self.value.identifier),
            .binary_operator, .unary_operator => {
                allocator.free(self.value.operator);
                if (self.args) |args| {
                    for (args) |*arg| {
                        arg.deinit(allocator);
                    }
                    allocator.free(args);
                }
            },
            .function => {
                allocator.free(self.value.function.name);
                if (self.args) |args| {
                    for (args) |*arg| {
                        arg.deinit(allocator);
                    }
                    allocator.free(args);
                }
            },
            .list => {
                if (self.args) |args| {
                    for (args) |*arg| {
                        arg.deinit(allocator);
                    }
                    allocator.free(args);
                }
            },
        }
    }
};

pub fn tokenize(allocator: std.mem.Allocator, expression: []const u8) ![]Token {
    if (expression.len == 0) {
        return &[_]Token{};
    }

    var tokens = std.ArrayList(Token).init(allocator);
    defer tokens.deinit();

    var i: usize = 0;
    const expr = expression;
    while (i < expr.len) {
        // Skip whitespace
        if (std.ascii.isWhitespace(expr[i])) {
            i += 1;
            continue;
        }

        // Handle negative numbers: look for minus sign followed by digit or decimal point
        if (expr[i] == '-' and i + 1 < expr.len and
            (std.ascii.isDigit(expr[i + 1]) or expr[i + 1] == '.'))
        {
            // Find the end of the number
            var j = i + 1;
            var has_e = false;
            while (j < expr.len) : (j += 1) {
                const c = expr[j];
                if (std.ascii.isDigit(c) or c == '.') continue;
                if ((c == 'e' or c == 'E') and !has_e) {
                    has_e = true;
                    if (j + 1 < expr.len and (expr[j + 1] == '+' or expr[j + 1] == '-')) {
                        j += 1;
                    }
                    continue;
                }
                break;
            }
            try tokens.append(.{
                .type = .number,
                .value = try allocator.dupe(u8, expr[i..j]),
            });
            i = j;
            continue;
        }

        // Match operators first
        if (i + 1 < expr.len and (std.mem.eql(u8, expr[i .. i + 2], "==") or
            std.mem.eql(u8, expr[i .. i + 2], "!=") or
            std.mem.eql(u8, expr[i .. i + 2], "<=") or
            std.mem.eql(u8, expr[i .. i + 2], ">=") or
            std.mem.eql(u8, expr[i .. i + 2], "**") or
            std.mem.eql(u8, expr[i .. i + 2], "//")))
        {
            try tokens.append(.{ .type = .operator, .value = try allocator.dupe(u8, expr[i .. i + 2]) });
            i += 2;
            continue;
        }

        // Single character operators and symbols
        if (std.mem.indexOfScalar(u8, "+-*/%()<>!=,[]", expr[i]) != null) {
            const c = [_]u8{expr[i]};
            try tokens.append(.{ .type = switch (expr[i]) {
                '(' => .left_paren,
                ')' => .right_paren,
                '[' => .left_bracket,
                ']' => .right_bracket,
                ',' => .comma,
                else => .operator,
            }, .value = try allocator.dupe(u8, &c) });
            i += 1;
            continue;
        }

        // Strings and date strings
        if (expr[i] == '\'' or expr[i] == '"' or (i + 1 < expr.len and expr[i] == 'd' and (expr[i + 1] == '\'' or expr[i + 1] == '"'))) {
            const is_date = i + 1 < expr.len and expr[i] == 'd' and (expr[i + 1] == '\'' or expr[i + 1] == '"');
            if (is_date and expr[i] != 'd') continue; // Make sure we only process 'd' as part of date string

            const quote = if (is_date) expr[i + 1] else expr[i];
            var j = if (is_date) i + 2 else i + 1;

            while (j < expr.len) : (j += 1) {
                if (expr[j] == quote and expr[j - 1] != '\\') break;
            }
            if (j < expr.len) j += 1;

            const token_type: TokenType = if (is_date) .date_string else .string;
            const token_value = try allocator.dupe(u8, expr[i..j]);
            try tokens.append(.{ .type = token_type, .value = token_value });

            i = j;
            continue;
        }

        // Identifiers and keywords - update to skip 'd' when it's followed by a quote
        if (std.ascii.isAlphabetic(expr[i]) or expr[i] == '_' or expr[i] == '$') {
            // Skip if this is a 'd' that starts a date string
            if (expr[i] == 'd' and i + 1 < expr.len and (expr[i + 1] == '\'' or expr[i + 1] == '"')) {
                continue;
            }

            var j = i + 1;
            while (j < expr.len and (std.ascii.isAlphanumeric(expr[j]) or expr[j] == '_' or expr[j] == '.')) : (j += 1) {}
            const word = expr[i..j];

            try tokens.append(.{ .type = if (binary_operators.has(word) or unary_operators.has(word))
                .operator
            else
                .identifier, .value = try allocator.dupe(u8, word) });
            i = j;
            continue;
        }

        // Numbers
        if (std.ascii.isDigit(expr[i]) or (expr[i] == '-' and i + 1 < expr.len and std.ascii.isDigit(expr[i + 1])) or (expr[i] == '.' and i + 1 < expr.len and std.ascii.isDigit(expr[i + 1]))) {
            var j = if (expr[i] == '-' or expr[i] == '.') i + 1 else i;
            var has_dot = false;
            var has_e = false;
            var has_sign = false;
            var e_index: usize = 0;
            while (j < expr.len) : (j += 1) {
                if (expr[j] == '.' and !has_dot) {
                    has_dot = true;
                    continue;
                }
                if (expr[j] == 'e' or expr[j] == 'E') {
                    has_e = true;
                    e_index = j;
                    continue;
                }
                if (has_e and (e_index == j - 1) and (expr[j] == '+' or expr[j] == '-')) {
                    has_sign = true;
                    continue;
                }
                if (!std.ascii.isDigit(expr[j])) break;
            }
            try tokens.append(.{ .type = .number, .value = try allocator.dupe(u8, expr[i..j]) });
            i = j;
            continue;
        }

        // Unrecognized character
        i += 1;
    }

    //  return the ArrayList
    return tokens.toOwnedSlice();
}

pub fn shunting_yard(allocator: std.mem.Allocator, tokens: []const Token) ![]Node {
    var output_queue = std.ArrayList(Node).init(allocator);
    errdefer {
        for (output_queue.items) |*node| {
            node.deinit(allocator);
        }
        output_queue.deinit();
    }

    var operator_stack = std.ArrayList(Token).init(allocator);
    defer operator_stack.deinit();

    var arg_count_stack = std.ArrayList(usize).init(allocator);
    defer arg_count_stack.deinit();

    var element_count_stack = std.ArrayList(usize).init(allocator);
    defer element_count_stack.deinit();

    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        const token = tokens[i];
        switch (token.type) {
            .number => {
                // Check if the number is an integer or float
                const is_float = std.mem.indexOf(u8, token.value, ".") != null or
                    std.mem.indexOf(u8, token.value, "e") != null or
                    std.mem.indexOf(u8, token.value, "E") != null or
                    token.value[0] == '.';

                if (is_float) {
                    const value = try std.fmt.parseFloat(f64, token.value);
                    try output_queue.append(Node{
                        .type = .literal_float,
                        .value = .{ .float = value },
                    });
                } else {
                    const value = try std.fmt.parseInt(i64, token.value, 10);
                    try output_queue.append(Node{
                        .type = .literal_integer,
                        .value = .{ .integer = value },
                    });
                }
            },
            .string => {
                const str_value = try allocator.dupe(u8, token.value[1 .. token.value.len - 1]);
                try output_queue.append(Node{
                    .type = .literal_string,
                    .value = .{ .string = str_value },
                });
            },
            .date_string => {
                const date_value = try allocator.dupe(u8, token.value[2 .. token.value.len - 1]);
                try output_queue.append(Node{
                    .type = .literal_date,
                    .value = .{ .date = date_value },
                });
            },
            .identifier => {
                if (!binary_operators.has(token.value) and !unary_operators.has(token.value)) {
                    // Check if next token is a left parenthesis (function call)
                    const is_function = if (i + 1 < tokens.len) tokens[i + 1].type == .left_paren else false;

                    if (is_function) {
                        // Push to operator stack as it will be processed when we hit the right paren
                        try operator_stack.append(token);
                    } else {
                        // Regular identifier
                        const id_value = try allocator.dupe(u8, token.value);
                        try output_queue.append(Node{
                            .type = .identifier,
                            .value = .{ .identifier = id_value },
                        });
                    }
                } else {
                    try operator_stack.append(token);
                }
            },
            .operator => try operator_stack.append(token),
            .left_paren => {
                try operator_stack.append(token);
                // If the previous token was an identifier, this is a function call
                // Initialize arg_count to 1 for the first argument
                if (operator_stack.items.len >= 2 and
                    operator_stack.items[operator_stack.items.len - 2].type == .identifier)
                {
                    try arg_count_stack.append(1);
                } else {
                    try arg_count_stack.append(0);
                }
            },
            .right_paren => {
                while (operator_stack.items.len > 0 and operator_stack.items[operator_stack.items.len - 1].type != .left_paren) {
                    const op = operator_stack.pop();
                    try handleOperator(&output_queue, op, allocator);
                }
                if (operator_stack.items.len == 0) {
                    return error.UnmatchedParentheses;
                }
                _ = operator_stack.pop(); // Remove left parenthesis

                if (arg_count_stack.items.len > 0) {
                    const arg_count = arg_count_stack.pop();
                    if (operator_stack.items.len > 0 and
                        operator_stack.items[operator_stack.items.len - 1].type == .identifier)
                    {
                        const fun = operator_stack.pop();
                        try handleFunction(&output_queue, fun, arg_count, allocator);
                    }
                }
            },
            .left_bracket => {
                try operator_stack.append(token);
                try element_count_stack.append(1); // First element
            },
            .right_bracket => {
                while (operator_stack.items.len > 0 and operator_stack.items[operator_stack.items.len - 1].type != .left_bracket) {
                    const op = operator_stack.pop();
                    try handleOperator(&output_queue, op, allocator);
                }
                if (operator_stack.items.len == 0) {
                    return error.UnmatchedBrackets;
                }
                _ = operator_stack.pop(); // Remove left bracket

                if (element_count_stack.items.len > 0) {
                    // Count the actual elements in the output queue
                    var element_count = element_count_stack.pop();
                    // If we have a trailing comma, the last token before this was a comma
                    // so we need to adjust the count
                    if (tokens.len >= 2 and tokens[tokens.len - 2].type == .comma) {
                        element_count -= 1;
                    }
                    try output_queue.append(Node{
                        .type = .list,
                        .value = .{ .list = .{ .element_count = element_count } },
                    });
                }
            },
            .comma => {
                while (operator_stack.items.len > 0 and
                    operator_stack.items[operator_stack.items.len - 1].type != .left_paren and
                    operator_stack.items[operator_stack.items.len - 1].type != .left_bracket)
                {
                    const op = operator_stack.pop();
                    try handleOperator(&output_queue, op, allocator);
                }

                if (arg_count_stack.items.len > 0) {
                    arg_count_stack.items[arg_count_stack.items.len - 1] += 1;
                }
                if (element_count_stack.items.len > 0) {
                    element_count_stack.items[element_count_stack.items.len - 1] += 1;
                }
            },
        }
    }

    // Pop remaining operators
    while (operator_stack.items.len > 0) {
        const op = operator_stack.pop();
        if (op.type == .left_paren or op.type == .right_paren) {
            return error.UnmatchedParentheses;
        }
        try handleOperator(&output_queue, op, allocator);
    }

    return output_queue.toOwnedSlice();
}

fn handleOperator(output_queue: *std.ArrayList(Node), op: Token, allocator: std.mem.Allocator) !void {
    const op_value = try allocator.dupe(u8, op.value);
    if (binary_operators.has(op.value)) {
        try output_queue.append(Node{
            .type = .binary_operator,
            .value = .{ .operator = op_value },
        });
    } else if (unary_operators.has(op.value)) {
        try output_queue.append(Node{
            .type = .unary_operator,
            .value = .{ .operator = op_value },
        });
    }
}

fn handleFunction(output_queue: *std.ArrayList(Node), fun: Token, arg_count: usize, allocator: std.mem.Allocator) !void {
    const fun_name = try allocator.dupe(u8, fun.value);
    try output_queue.append(Node{
        .type = .function,
        .value = .{ .function = .{
            .name = fun_name,
            .arg_count = arg_count,
        } },
    });
}

pub const ParseTree = struct {
    root: Node,

    pub fn deinit(self: *ParseTree, allocator: std.mem.Allocator) void {
        self.root.deinit(allocator);
    }
};

pub fn parse_to_tree(allocator: std.mem.Allocator, expression: []const u8) !ParseTree {
    // First tokenize the expression
    const tokens = try tokenize(allocator, expression);
    defer {
        for (tokens) |token| {
            allocator.free(token.value);
        }
        allocator.free(tokens);
    }

    // Convert to RPN using shunting yard
    const rpn = try shunting_yard(allocator, tokens);
    defer {
        for (rpn) |*node| {
            node.deinit(allocator);
        }
        allocator.free(rpn);
    }

    if (rpn.len == 0) {
        return error.EmptyExpression;
    }

    // Build the parse tree from RPN
    var stack = std.ArrayList(Node).init(allocator);
    defer stack.deinit();

    // Track nodes that should not be cleaned up
    var owned_nodes = std.ArrayList(Node).init(allocator);
    defer {
        for (owned_nodes.items) |*node| {
            node.deinit(allocator);
        }
        owned_nodes.deinit();
    }

    for (rpn) |node| {
        switch (node.type) {
            .literal_integer, .literal_float, .literal_string, .literal_date, .identifier => {
                var cloned = try cloneNode(allocator, node);
                errdefer cloned.deinit(allocator);
                try stack.append(cloned);
                try owned_nodes.append(cloned);
            },
            .unary_operator => {
                if (stack.items.len < 1) return error.InvalidExpression;

                var new_node = try cloneNode(allocator, node);
                errdefer new_node.deinit(allocator);

                var args = try allocator.alloc(Node, 1);
                errdefer allocator.free(args);

                // Move ownership of the argument
                const arg = stack.pop();
                if (owned_nodes.items.len > 0) {
                    _ = owned_nodes.orderedRemove(owned_nodes.items.len - 1);
                }
                args[0] = arg;
                new_node.args = args;
                try stack.append(new_node);
                try owned_nodes.append(new_node);
            },
            .binary_operator => {
                if (stack.items.len < 2) return error.InvalidExpression;

                var new_node = try cloneNode(allocator, node);
                errdefer new_node.deinit(allocator);

                var args = try allocator.alloc(Node, 2);
                errdefer allocator.free(args);

                // Move ownership of the arguments
                args[1] = stack.pop();
                if (owned_nodes.items.len > 0) {
                    _ = owned_nodes.orderedRemove(owned_nodes.items.len - 1);
                }
                args[0] = stack.pop();
                if (owned_nodes.items.len > 0) {
                    _ = owned_nodes.orderedRemove(owned_nodes.items.len - 1);
                }
                new_node.args = args;
                try stack.append(new_node);
                try owned_nodes.append(new_node);
            },
            .function => {
                const arg_count = node.value.function.arg_count;
                if (stack.items.len < arg_count) return error.InvalidExpression;

                var new_node = try cloneNode(allocator, node);
                errdefer new_node.deinit(allocator);

                var args = try allocator.alloc(Node, arg_count);
                errdefer allocator.free(args);

                var i: usize = arg_count;
                while (i > 0) {
                    i -= 1;
                    args[i] = stack.pop();
                    if (owned_nodes.items.len > 0) {
                        _ = owned_nodes.orderedRemove(owned_nodes.items.len - 1);
                    }
                }
                new_node.args = args;
                try stack.append(new_node);
                try owned_nodes.append(new_node);
            },
            .list => {
                const element_count = node.value.list.element_count;
                if (stack.items.len < element_count) return error.InvalidExpression;

                var new_node = try cloneNode(allocator, node);
                errdefer new_node.deinit(allocator);

                var elements = try allocator.alloc(Node, element_count);
                errdefer allocator.free(elements);

                var i: usize = element_count;
                while (i > 0) {
                    i -= 1;
                    elements[i] = stack.pop();
                    if (owned_nodes.items.len > 0) {
                        _ = owned_nodes.orderedRemove(owned_nodes.items.len - 1);
                    }
                }
                new_node.args = elements;
                try stack.append(new_node);
                try owned_nodes.append(new_node);
            },
        }
    }

    if (stack.items.len != 1) return error.InvalidExpression;

    // Take ownership of the final node
    var result = stack.pop();
    _ = owned_nodes.pop(); // Remove the result node from owned_nodes to prevent double-free
    return ParseTree{ .root = result };
}

fn cloneNode(allocator: std.mem.Allocator, node: Node) !Node {
    var new_node = Node{
        .type = node.type,
        .value = undefined,
        .args = null,
    };

    switch (node.type) {
        .literal_integer => new_node.value = .{ .integer = node.value.integer },
        .literal_float => new_node.value = .{ .float = node.value.float },
        .literal_string => new_node.value = .{ .string = try allocator.dupe(u8, node.value.string) },
        .literal_date => new_node.value = .{ .date = try allocator.dupe(u8, node.value.date) },
        .identifier => new_node.value = .{ .identifier = try allocator.dupe(u8, node.value.identifier) },
        .binary_operator, .unary_operator => new_node.value = .{ .operator = try allocator.dupe(u8, node.value.operator) },
        .function => new_node.value = .{ .function = .{
            .name = try allocator.dupe(u8, node.value.function.name),
            .arg_count = node.value.function.arg_count,
        } },
        .list => new_node.value = .{ .list = .{
            .element_count = node.value.list.element_count,
        } },
    }

    return new_node;
}

// Update the test to use standard Zig types
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
