const std = @import("std");
const Node = @import("term_parser.zig").Node;
const parse_to_tree = @import("term_parser.zig").parse_to_tree;
const Allocator = std.mem.Allocator;
const builtin_env = @import("builtin_env.zig"); // Assume this contains your built-in functions

pub const Value = union(enum) {
    integer: i64,
    float: f64,
    boolean: bool,
    string: []const u8,
    date: []const u8,
    list: []Value,
    function: *const fn (args: []const Value) InterpreterError!Value,
};

pub const InterpreterError = error{
    UndefinedIdentifier,
    InvalidOperation,
    DivisionByZero,
    TypeError,
    InvalidArgCount,
    OutOfMemory,
};

pub const Environment = struct {
    store: std.StringHashMap(Value),
    parent: ?*Environment,

    pub fn init(allocator: Allocator, parent: ?*Environment) Environment {
        return .{
            .store = std.StringHashMap(Value).init(allocator),
            .parent = parent,
        };
    }

    pub fn deinit(self: *Environment) void {
        self.store.deinit();
    }

    pub fn get(self: *const Environment, name: []const u8) ?Value {
        if (self.store.get(name)) |value| {
            return value;
        } else if (self.parent) |parent| {
            return parent.get(name);
        } else {
            return null;
        }
    }

    pub fn put(self: *Environment, name: []const u8, value: Value) !void {
        try self.store.put(name, value);
    }
};

pub const CompareOp = enum { gt, lt, eq, neq };

pub fn evaluate(allocator: Allocator, node: *const Node, env: *Environment) InterpreterError!Value {
    return switch (node.type) {
        .literal_integer => Value{ .integer = node.value.integer },
        .literal_float => Value{ .float = node.value.float },
        .literal_string => Value{ .string = node.value.string },
        .literal_date => Value{ .date = node.value.date },
        .identifier => env.get(node.value.identifier) orelse return error.UndefinedIdentifier,
        .binary_operator => try evaluateBinaryOperator(allocator, node, env),
        .unary_operator => try evaluateUnaryOperator(allocator, node, env),
        .function => try evaluateFunction(allocator, node, env),
        .list => try evaluateList(allocator, node, env),
    };
}

fn evaluateBinaryOperator(allocator: Allocator, node: *const Node, env: *Environment) InterpreterError!Value {
    if (node.args == null or node.args.?.len < 2) return error.InvalidArgCount;

    const left = try evaluate(allocator, &node.args.?[0], env);
    const right = try evaluate(allocator, &node.args.?[1], env);

    return switch (node.value.operator[0]) {
        '+' => addValues(left, right),
        '-' => subtractValues(left, right),
        '*' => multiplyValues(left, right),
        '/' => divideValues(left, right),
        '>' => compareValues(left, right, .gt),
        '<' => compareValues(left, right, .lt),
        '=' => compareValues(left, right, .eq),
        '!' => compareValues(left, right, .neq),
        else => return error.InvalidOperation,
    };
}

fn evaluateUnaryOperator(allocator: Allocator, node: *const Node, env: *Environment) InterpreterError!Value {
    if (node.args == null or node.args.?.len < 1) return error.InvalidArgCount;

    const operand = try evaluate(allocator, &node.args.?[0], env);

    return switch (node.value.operator[0]) {
        'n' => negateValue(operand),
        '!' => notValue(operand),
        else => return error.InvalidOperation,
    };
}

fn evaluateFunction(allocator: Allocator, node: *const Node, env: *Environment) InterpreterError!Value {
    const func_name = node.value.function.name;
    const func = builtin_env.get(func_name) orelse return error.UndefinedIdentifier;

    var args = try allocator.alloc(Value, node.value.function.arg_count);
    defer allocator.free(args);

    if (node.args == null or node.args.?.len < node.value.function.arg_count) {
        return error.InvalidArgCount;
    }

    for (0..node.value.function.arg_count) |i| {
        args[i] = try evaluate(allocator, &node.args.?[i], env);
    }

    return func(args) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.TypeError => error.TypeError,
        error.InvalidArgCount => error.InvalidArgCount,
        error.DivisionByZero => error.DivisionByZero,
        else => error.InvalidOperation,
    };
}

fn evaluateList(allocator: Allocator, node: *const Node, env: *Environment) InterpreterError!Value {
    if (node.args == null) return error.InvalidArgCount;

    const elements = try allocator.alloc(Value, node.value.list.element_count);
    errdefer allocator.free(elements);

    for (0..node.value.list.element_count) |i| {
        elements[i] = try evaluate(allocator, &node.args.?[i], env);
    }
    return Value{ .list = elements };
}

// Helper functions for operations
fn addValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| Value{ .integer = l + r },
            .float => |r| Value{ .float = @as(f64, @floatFromInt(l)) + r },
            else => return error.TypeError,
        },
        .float => |l| switch (right) {
            .integer => |r| Value{ .float = l + @as(f64, @floatFromInt(r)) },
            .float => |r| Value{ .float = l + r },
            else => return error.TypeError,
        },
        else => return error.TypeError,
    };
}

fn subtractValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| Value{ .integer = l - r },
            .float => |r| Value{ .float = @as(f64, @floatFromInt(l)) - r },
            else => error.TypeError,
        },
        .float => |l| switch (right) {
            .integer => |r| Value{ .float = l - @as(f64, @floatFromInt(r)) },
            .float => |r| Value{ .float = l - r },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn multiplyValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| Value{ .integer = l * r },
            .float => |r| Value{ .float = @as(f64, @floatFromInt(l)) * r },
            else => error.TypeError,
        },
        .float => |l| switch (right) {
            .integer => |r| Value{ .float = l * @as(f64, @floatFromInt(r)) },
            .float => |r| Value{ .float = l * r },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn divideValues(left: Value, right: Value) InterpreterError!Value {
    return switch (right) {
        .integer => |r| if (r == 0) error.DivisionByZero else switch (left) {
            .integer => |l| Value{ .integer = @divTrunc(l, r) },
            .float => |l| Value{ .float = l / @as(f64, @floatFromInt(r)) },
            else => error.TypeError,
        },
        .float => |r| if (r == 0.0) error.DivisionByZero else switch (left) {
            .integer => |l| Value{ .float = @as(f64, @floatFromInt(l)) / r },
            .float => |l| Value{ .float = l / r },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn compareValues(left: Value, right: Value, op: CompareOp) InterpreterError!Value {
    const Compare = struct {
        fn nums(a: f64, b: f64, operation: CompareOp) bool {
            return switch (operation) {
                .gt => a > b,
                .lt => a < b,
                .eq => a == b,
                .neq => a != b,
            };
        }

        fn strings(a: []const u8, b: []const u8, operation: CompareOp) bool {
            const cmp = std.mem.order(u8, a, b);
            return switch (operation) {
                .gt => cmp == .gt,
                .lt => cmp == .lt,
                .eq => cmp == .eq,
                .neq => cmp != .eq,
            };
        }
    };

    return switch (left) {
        .integer => |i| Value{ .boolean = Compare.nums(@as(f64, @floatFromInt(i)), try valueToFloat(right), op) },
        .float => |f| Value{ .boolean = Compare.nums(f, try valueToFloat(right), op) },
        .boolean => |b| Value{ .boolean = Compare.nums(if (b) 1 else 0, try valueToFloat(right), op) },
        .string => |s1| switch (right) {
            .string => |s2| Value{ .boolean = Compare.strings(s1, s2, op) },
            else => return error.TypeError,
        },
        .date => |d1| switch (right) {
            .date => |d2| Value{ .boolean = Compare.strings(d1, d2, op) },
            else => return error.TypeError,
        },
        else => return error.TypeError,
    };
}

// Helper function to convert Value to f64
fn valueToFloat(value: Value) InterpreterError!f64 {
    return switch (value) {
        .integer => |i| @as(f64, @floatFromInt(i)),
        .float => |f| f,
        .boolean => |b| if (b) 1 else 0,
        else => error.TypeError,
    };
}

fn negateValue(value: Value) InterpreterError!Value {
    return switch (value) {
        .integer => |v| Value{ .integer = -v },
        .float => |v| Value{ .float = -v },
        else => return error.TypeError,
    };
}

fn notValue(value: Value) InterpreterError!Value {
    return switch (value) {
        .boolean => |v| Value{ .boolean = !v },
        else => return error.TypeError,
    };
}

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
