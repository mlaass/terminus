const std = @import("std");
const py = @import("pydust");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");

// Export Python functions
pub fn tokenize(args: struct { expression: []const u8 }) !py.PyList {
    const allocator = std.heap.page_allocator;

    // const expression: []const u8 = try py.PyString.asSlice(args.expression);
    std.debug.print("expression: {s}\n", .{args.expression});

    const tokens = try parser.tokenize(allocator, args.expression);
    defer {
        for (tokens) |token| {
            allocator.free(token.value);
        }
        allocator.free(tokens);
    }
    const py_tokens = try py.PyList.new(0);
    // const pt = try py.PyList.new(tokens.len);

    for (tokens) |token| {
        const py_token = try py.PyString.create(token.value);
        std.debug.print("token: {s} ({s})\n", .{ token.value, @tagName(token.type) });
        try py_tokens.append(py_token);
    }
    return py_tokens;
}
// TODO: Implement the python frontend for parse_to_tree

// pub fn parse_to_tree(args: struct { expression: []const u8 }) !py.PyObject {
//     const allocator = std.heap.page_allocator;
//     const tree = try parser.parse_to_tree(allocator, args.expression);
//     defer tree.deinit();
//     return tree.node.toPyObject();
// }
// // TODO: Implement the python frontend for evaluate

// pub fn evaluate(args: struct { expression: []const u8 }) !py.PyObject {
//     const allocator = std.heap.page_allocator;
//     const result = try interpreter.evaluate(allocator, args.expression);
//     defer result.deinit();
//     return result.toPyObject();
// }

comptime {
    py.rootmodule(@This());
}
