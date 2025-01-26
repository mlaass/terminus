const std = @import("std");

const TokenType = enum {
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

const Token = struct {
    type: TokenType,
    value: []const u8,
};

// Token patterns for lexical analysis
const patterns = struct {
    const whitespace = "\\s+";
    const operators = "=>|//|\\*\\*|==|!=|<=|>=|<<|>>|\\|{1,2}|&|\\^";
    const date_string = "d\"(?:\\\\.|[^\"\\\\])*\"|d'(?:\\\\.|[^'\\\\])*'";
    const string = "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'";
    const number = "-?\\d*\\.\\d+|-?\\.\\d+|-?\\d+\\b";
    const identifier = "\\$[\\w\\.]+|\\b[\\w\\.]+\\b";
    const symbol = "[+\\-*/%(),<>!=]";
};

// Binary operators and their precedence
const binary_operators = std.ComptimeStringMap(u8, .{
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
const unary_operators = std.ComptimeStringMap(void, .{
    .{ "not", {} },
    .{ "neg", {} },
    .{ "floor", {} },
    .{ "ceil", {} },
    .{ "abs", {} },
    .{ "int", {} },
    .{ "float", {} },
    .{ "bool", {} },
});

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
        if (std.ascii.isDigit(expr[i]) or (expr[i] == '-' and i + 1 < expr.len and std.ascii.isDigit(expr[i + 1]))) {
            var j = if (expr[i] == '-') i + 1 else i;
            var has_dot = false;
            while (j < expr.len) : (j += 1) {
                if (expr[j] == '.' and !has_dot) {
                    has_dot = true;
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

pub const ParseTree = struct {
    // Define your parse tree structure here
    // This is a placeholder - implement based on your needs
    value: []const u8,

    pub fn deinit(self: *ParseTree, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
    }
};

pub fn parse_to_tree(allocator: std.mem.Allocator, expression: []const u8) !ParseTree {
    _ = expression;
    // TODO: Implement parsing
    const value = try allocator.dupe(u8, "hello");
    return ParseTree{ .value = value };
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
