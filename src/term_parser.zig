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
    .{ "!", {} },
    .{ "-", {} },
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
        if (std.mem.indexOfScalar(u8, "+-*/%()<>!=,[]!", expr[i]) != null) {
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
            .operator => {
                // While there's an operator on top of the stack with greater precedence
                // or equal precedence and left associativity
                while (operator_stack.items.len > 0) {
                    const top = operator_stack.items[operator_stack.items.len - 1];
                    if (top.type == .left_paren) break;

                    const curr_prec = if (unary_operators.has(token.value))
                        100 // Give unary operators highest precedence
                    else
                        binary_operators.get(token.value) orelse 0;

                    const top_prec = if (unary_operators.has(top.value))
                        100 // Give unary operators highest precedence
                    else
                        binary_operators.get(top.value) orelse 0;

                    // For left-associative operators, pop when top_prec >= curr_prec
                    if (top_prec < curr_prec) break;

                    // Pop the operator and add it to the output
                    const op = operator_stack.pop();
                    try handleOperator(&output_queue, op, allocator);
                }
                try operator_stack.append(token);
            },
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
                // When we hit a right parenthesis, pop operators until we find the matching left parenthesis
                while (operator_stack.items.len > 0 and
                    operator_stack.items[operator_stack.items.len - 1].type != .left_paren)
                {
                    const op = operator_stack.pop();
                    try handleOperator(&output_queue, op, allocator);
                }
                if (operator_stack.items.len == 0) {
                    return error.UnmatchedParentheses;
                }
                _ = operator_stack.pop(); // Remove left parenthesis

                // If the top of the stack is a function token, pop it too
                if (operator_stack.items.len > 0 and
                    operator_stack.items[operator_stack.items.len - 1].type == .identifier)
                {
                    const fun = operator_stack.pop();
                    try handleFunction(&output_queue, fun, arg_count_stack.pop(), allocator);
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

    // Pop any remaining operators
    while (operator_stack.items.len > 0) {
        const op = operator_stack.pop();
        if (op.type == .left_paren or op.type == .right_paren) {
            return error.UnmatchedParentheses;
        }
        try handleOperator(&output_queue, op, allocator);
    }

    return output_queue.toOwnedSlice();
}

fn handleOperator(output_queue: *std.ArrayList(Node), token: Token, allocator: std.mem.Allocator) !void {
    // Check if it's a unary operator
    if (unary_operators.has(token.value)) {
        try output_queue.append(Node{
            .type = .unary_operator,
            .value = .{ .operator = try allocator.dupe(u8, token.value) },
        });
    } else {
        // Binary operator
        try output_queue.append(Node{
            .type = .binary_operator,
            .value = .{ .operator = try allocator.dupe(u8, token.value) },
        });
    }
}

fn handleFunction(output_queue: *std.ArrayList(Node), token: Token, arg_count: usize, allocator: std.mem.Allocator) !void {
    try output_queue.append(Node{
        .type = .function,
        .value = .{ .function = .{
            .name = try allocator.dupe(u8, token.value),
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
