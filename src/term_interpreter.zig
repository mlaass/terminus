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

pub const CompareOp = enum { gt, lt, eq, neq, gte, lte };

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

    // Get the full operator string from node
    const op = node.value.operator;

    return switch (op[0]) {
        '+' => addValues(left, right),
        '-' => subtractValues(left, right),
        '*' => if (op.len > 1 and op[1] == '*')
            powerValues(left, right)
        else
            multiplyValues(left, right),
        '/' => if (op.len > 1 and op[1] == '/')
            floorDivValues(left, right)
        else
            divideValues(left, right),
        '>' => if (op.len > 1 and op[1] == '=')
            compareValues(left, right, .gte)
        else
            compareValues(left, right, .gt),
        '<' => if (op.len > 1 and op[1] == '=')
            compareValues(left, right, .lte)
        else
            compareValues(left, right, .lt),
        '=' => compareValues(left, right, .eq),
        '!' => compareValues(left, right, .neq),
        '%' => moduloValues(left, right),
        '|' => bitwiseOrValues(left, right),
        '&' => bitwiseAndValues(left, right),
        else => if (std.mem.eql(u8, op, "mod"))
            moduloValues(left, right)
        else if (std.mem.eql(u8, op, "and"))
            logicalAndValues(left, right)
        else if (std.mem.eql(u8, op, "or"))
            logicalOrValues(left, right)
        else if (std.mem.eql(u8, op, "xor"))
            bitwiseXorValues(left, right)
        else if (std.mem.eql(u8, op, "<<"))
            bitShiftLeftValues(left, right)
        else if (std.mem.eql(u8, op, ">>"))
            bitShiftRightValues(left, right)
        else
            return error.InvalidOperation,
    };
}

fn evaluateUnaryOperator(allocator: Allocator, node: *const Node, env: *Environment) InterpreterError!Value {
    if (node.args == null or node.args.?.len < 1) return error.InvalidArgCount;

    const operand = try evaluate(allocator, &node.args.?[0], env);
    std.debug.print("operand: {any}\n", .{operand});
    return switch (node.value.operator[0]) {
        'n' => negateValue(operand),
        '!' => notValue(operand),
        else => return error.InvalidOperation,
    };
}

fn evaluateFunction(allocator: Allocator, node: *const Node, env: *Environment) InterpreterError!Value {
    var args = try allocator.alloc(Value, node.value.function.arg_count);
    defer {
        for (args) |arg| {
            deinitValue(allocator, arg);
        }
        allocator.free(args);
    }

    for (0..node.value.function.arg_count) |i| {
        args[i] = try evaluate(allocator, &node.args.?[i], env);
    }

    // TODO: get the function from env not builtin_env
    const func = builtin_env.get(node.value.function.name) orelse return error.UndefinedIdentifier;
    const func_result = try func(args);

    return func_result;
}

fn evaluateList(allocator: Allocator, node: *const Node, env: *Environment) InterpreterError!Value {
    if (node.args == null) return error.InvalidArgCount;

    const elements = try allocator.alloc(Value, node.value.list.element_count);
    errdefer {
        for (elements) |element| {
            deinitValue(allocator, element);
        }
        allocator.free(elements);
    }

    for (0..node.value.list.element_count) |i| {
        elements[i] = try evaluate(allocator, &node.args.?[i], env);
    }

    return Value{ .list = elements };
}

// Add this function to help manage list memory
pub fn deinitValue(allocator: Allocator, value: Value) void {
    switch (value) {
        .list => |list| {
            for (list) |element| {
                deinitValue(allocator, element);
            }
            allocator.free(list);
        },
        else => {}, // Other value types don't need cleanup
    }
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
                .gte => a >= b,
                .lte => a <= b,
            };
        }

        fn strings(a: []const u8, b: []const u8, operation: CompareOp) bool {
            const cmp = std.mem.order(u8, a, b);
            return switch (operation) {
                .gt => cmp == .gt,
                .lt => cmp == .lt,
                .eq => cmp == .eq,
                .neq => cmp != .eq,
                .gte => cmp != .lt,
                .lte => cmp != .gt,
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
        .boolean => |v| Value{ .boolean = !v },
        else => return error.TypeError,
    };
}

fn notValue(value: Value) InterpreterError!Value {
    return switch (value) {
        .boolean => |v| Value{ .boolean = !v },
        else => return error.TypeError,
    };
}

fn powerValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| if (r >= 0)
                Value{ .integer = std.math.pow(i64, l, @as(u6, @intCast(@min(@as(u64, @intCast(r)), 63)))) }
            else
                Value{ .float = std.math.pow(f64, @as(f64, @floatFromInt(l)), @as(f64, @floatFromInt(r))) },
            .float => |r| Value{ .float = std.math.pow(f64, @as(f64, @floatFromInt(l)), r) },
            else => error.TypeError,
        },
        .float => |l| switch (right) {
            .integer => |r| Value{ .float = std.math.pow(f64, l, @as(f64, @floatFromInt(r))) },
            .float => |r| Value{ .float = std.math.pow(f64, l, r) },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn floorDivValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| if (r == 0)
                error.DivisionByZero
            else
                Value{ .integer = @divFloor(l, r) },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn moduloValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| if (r == 0)
                error.DivisionByZero
            else
                Value{ .integer = @mod(l, r) },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn logicalAndValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .boolean => |l| switch (right) {
            .boolean => |r| Value{ .boolean = l and r },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn logicalOrValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .boolean => |l| switch (right) {
            .boolean => |r| Value{ .boolean = l or r },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn bitwiseAndValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| Value{ .integer = l & r },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn bitwiseOrValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| Value{ .integer = l | r },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn bitwiseXorValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| Value{ .integer = l ^ r },
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn bitShiftLeftValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| if (r >= 0)
                Value{ .integer = l << @intCast(@min(@as(u64, @intCast(r)), 63)) }
            else
                error.InvalidOperation,
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}

fn bitShiftRightValues(left: Value, right: Value) InterpreterError!Value {
    return switch (left) {
        .integer => |l| switch (right) {
            .integer => |r| if (r >= 0)
                Value{ .integer = l >> @intCast(@min(@as(u64, @intCast(r)), 63)) }
            else
                error.InvalidOperation,
            else => error.TypeError,
        },
        else => error.TypeError,
    };
}
