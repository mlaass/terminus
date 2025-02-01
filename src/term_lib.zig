const std = @import("std");
const py = @import("pydust");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");
const Environment = @import("interpreter_environment.zig").Environment;

fn raiseError(err: anyerror) !py.PyObject {
    switch (err) {
        error.DivisionByZero => {
            return py.ZeroDivisionError.raise("division by zero");
        },
        error.TypeError => {
            return py.TypeError.raise("invalid operand type");
        },
        error.InvalidOperation => {
            return py.ValueError.raise("invalid operation");
        },
        error.UndefinedIdentifier => {
            return py.NameError.raise("undefined identifier");
        },
        error.UnmatchedParentheses => {
            return py.ValueError.raise("unmatched parentheses");
        },
        else => {
            return py.RuntimeError.raiseFmt("error: {s}", .{@errorName(err)});
        },
    }
}

// Convert Value to PyObject
fn valueToPyObject(value: interpreter.Value) !py.PyObject {
    return switch (value.data) {
        .integer => |i| (try py.PyLong.create(i)).obj,
        .float => |f| (try py.PyFloat.create(f)).obj,
        .boolean => |b| if (b) py.True().obj else py.False().obj,
        .string => |s| (try py.PyString.create(s)).obj,
        .date => |d| (try py.PyString.create(d)).obj,
        .list => |list| blk: {
            var py_list = try py.PyList.new(0);
            for (list) |item| {
                const py_item = try valueToPyObject(item);
                try py_list.append(py_item);
            }
            break :blk py_list.obj;
        },
        .function => py.None(),
        .function_def => py.None(),
    };
}

// Export Python functions
pub fn tokenize(args: struct { expression: []const u8 }) !py.PyObject {
    const allocator = std.heap.page_allocator;

    const tokens = parser.tokenize(allocator, args.expression) catch |err| return raiseError(err);
    defer {
        for (tokens) |token| {
            allocator.free(token.value);
        }
        allocator.free(tokens);
    }
    const py_tokens = try py.PyList.new(0);

    for (tokens) |token| {
        const py_token = try py.PyString.create(token.value);
        try py_tokens.append(py_token);
    }
    return py_tokens.obj;
}

pub fn evaluate(args: struct { expression: []const u8 }) !py.PyObject {
    const allocator = std.heap.page_allocator;
    var env = Environment.init(allocator, null);
    defer env.deinit();

    // Parse the expression into a tree
    var tree = parser.parse_to_tree(allocator, args.expression) catch |err| return raiseError(err);
    defer tree.deinit(allocator);

    // Evaluate the tree
    const result = interpreter.evaluate(allocator, &tree.root, &env) catch |err| return raiseError(err);
    defer result.deinit();

    // Convert the result to a Python object
    return valueToPyObject(result);
}

comptime {
    py.rootmodule(@This());
}
