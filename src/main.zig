const std = @import("std");
const parse_to_tree = @import("parser.zig").parse_to_tree;
const evaluate = @import("interpreter.zig").evaluate;
const Environment = @import("interpreter_environment.zig").Environment;
const tokenize = @import("parser.zig").tokenize;
const shunting_yard = @import("parser.zig").shunting_yard;
const Node = @import("parser.zig").Node;

fn printNode(node: Node) void {
    switch (node.type) {
        .literal_integer => std.debug.print("int({d})", .{node.value.integer}),
        .literal_float => std.debug.print("float({d})", .{node.value.float}),
        .literal_string => std.debug.print("string(\"{s}\")", .{node.value.string}),
        .literal_date => std.debug.print("date(\"{s}\")", .{node.value.date}),
        .identifier => std.debug.print("id({s})", .{node.value.identifier}),
        .binary_operator => std.debug.print("binop({s})", .{node.value.operator}),
        .unary_operator => std.debug.print("unop({s})", .{node.value.operator}),
        .function => std.debug.print("func({s}, args={d})", .{ node.value.function.name, node.value.function.arg_count }),
        .list => std.debug.print("list(elements={d})", .{node.value.list.element_count}),
    }
}

pub fn printNodeTree(node: *const Node, depth: usize) void {
    // Print indentation
    for (0..depth) |_| {
        std.debug.print("  ", .{});
    }

    // Print the node itself
    printNode(node.*);
    std.debug.print("\n", .{});

    // Print children if any
    if (node.args) |args| {
        for (args) |*arg| {
            printNodeTree(arg, depth + 1);
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} [--parse] [--rpn] [--tree] \"expression\"\n", .{args[0]});
        std.debug.print("Options:\n", .{});
        std.debug.print("  --parse  Print tokenization results\n", .{});
        std.debug.print("  --rpn    Print reverse polish notation output\n", .{});
        std.debug.print("  --tree   Print parse tree\n", .{});
        std.debug.print("\nExample: {s} --tree \"5 + 3 * 2\"\n", .{args[0]});
        std.process.exit(1);
    }

    var show_parse = false;
    var show_rpn = false;
    var show_tree = false;
    var expression: ?[]const u8 = null;

    // Parse command line arguments
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--parse")) {
            show_parse = true;
        } else if (std.mem.eql(u8, arg, "--rpn")) {
            show_rpn = true;
        } else if (std.mem.eql(u8, arg, "--tree")) {
            show_tree = true;
        } else if (expression == null) {
            expression = arg;
        }
    }

    if (expression == null) {
        std.debug.print("Error: No expression provided\n", .{});
        std.process.exit(1);
    }

    // Debug: Show tokenization results
    if (show_parse) {
        const tokens = try tokenize(allocator, expression.?);
        defer {
            for (tokens) |token| {
                allocator.free(token.value);
            }
            allocator.free(tokens);
        }

        std.debug.print("\nTokenization results:\n", .{});
        for (tokens, 0..) |token, i| {
            std.debug.print("{d}: {s} ({s})\n", .{ i + 1, token.value, @tagName(token.type) });
        }
    }

    // Debug: Show reverse polish notation output
    if (show_rpn) {
        const tokens = try tokenize(allocator, expression.?);
        defer {
            for (tokens) |token| {
                allocator.free(token.value);
            }
            allocator.free(tokens);
        }

        const rpn = try shunting_yard(allocator, tokens);
        defer {
            for (rpn) |*node| {
                node.deinit(allocator);
            }
            allocator.free(rpn);
        }

        std.debug.print("\nReverse Polish Notation output (RPN):\n", .{});
        for (rpn, 0..) |node, i| {
            std.debug.print("{d}: ", .{i + 1});
            printNode(node);
            std.debug.print("\n", .{});
        }
    }

    var env = Environment.init(allocator, null);
    defer env.deinit();

    var tree = try parse_to_tree(allocator, expression.?);
    defer tree.deinit(allocator);

    // Debug: Show parse tree
    if (show_tree) {
        std.debug.print("\nParse tree:\n", .{});
        printNodeTree(&tree.root, 0);
        std.debug.print("\n", .{});
    }

    var result = try evaluate(allocator, &tree.root, &env);
    defer result.deinit();

    // Always print the result
    std.debug.print("Result: ", .{});
    switch (result.data) {
        .integer => |v| std.debug.print("{d}\n", .{v}),
        .float => |v| std.debug.print("{d}\n", .{v}),
        .boolean => |v| std.debug.print("{}\n", .{v}),
        .string => |v| std.debug.print("{s}\n", .{v}),
        .date => |v| std.debug.print("{s}\n", .{v}),
        .function_def => std.debug.print("<function_def> {s}\n", .{result.data.function_def.node.value.function.name}),
        .list => |v| {
            std.debug.print("[", .{});
            for (v, 0..) |item, i| {
                switch (item.data) {
                    .integer => |n| std.debug.print("{d}", .{n}),
                    .float => |n| std.debug.print("{d}", .{n}),
                    .boolean => |b| std.debug.print("{}", .{b}),
                    .string => |s| std.debug.print("\"{s}\"", .{s}),
                    .date => |d| std.debug.print("d'{s}'", .{d}),
                    .list => std.debug.print("...", .{}),
                    .function => std.debug.print("<function>", .{}),
                    .function_def => std.debug.print("<function_def>", .{}),
                }
                if (i < v.len - 1) std.debug.print(", ", .{});
            }
            std.debug.print("]\n", .{});
        },
        .function => std.debug.print("<function>\n", .{}),
    }
}
