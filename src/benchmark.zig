const std = @import("std");
const Environment = @import("interpreter_environment.zig").Environment;
const Value = @import("interpreter.zig").Value;
const parse_to_tree = @import("parser.zig").parse_to_tree;
const evaluate = @import("interpreter.zig").evaluate;

const TestExpression = struct {
    expr: []const u8,
    name: []const u8,
};

const test_expressions = [_]TestExpression{
    // Simple arithmetic
    .{ .expr = "5 + 3", .name = "simple_add" },
    .{ .expr = "10 - 4", .name = "simple_sub" },
    .{ .expr = "3 * 4", .name = "simple_mul" },
    .{ .expr = "10 / 2", .name = "simple_div" },
    // Complex arithmetic
    .{ .expr = "42 + 5", .name = "complex_add" },
    .{ .expr = "42 + 3.14", .name = "mixed_add" },
    .{ .expr = "10 / 3", .name = "integer_div" },
    .{ .expr = "2 * (3 + 4) - 5", .name = "nested_arithmetic" },
    // Literals
    .{ .expr = "42", .name = "integer_literal" },
    .{ .expr = "3.14", .name = "float_literal" },
    .{ .expr = "'hello'", .name = "string_literal" },
    .{ .expr = "d'2023-01-01'", .name = "date_literal" },
    .{ .expr = "[1, 2, 3]", .name = "list_literal" },
    // Comparisons
    .{ .expr = "5 > 3", .name = "comparison_gt" },
    .{ .expr = "5 < 3", .name = "comparison_lt" },
    .{ .expr = "5 == 5", .name = "comparison_eq" },
    .{ .expr = "5 != 3", .name = "comparison_neq" },
    .{ .expr = "'abc' == 'def'", .name = "string_comparison" },
    // Boolean operations
    .{ .expr = "(5 < 3)", .name = "simple_bool" },
    .{ .expr = "(5 > 3) and (2 < 4)", .name = "bool_and" },
    .{ .expr = "(5 < 3) or (2 < 4)", .name = "bool_or" },
};

fn benchmarkExpression(allocator: std.mem.Allocator, expr: []const u8, iterations: usize) !struct { min: i64, max: i64, avg: f64 } {
    var env = Environment.init(allocator, null);
    defer env.deinit();

    var timer = try std.time.Timer.start();
    var min_time: i64 = std.math.maxInt(i64);
    var max_time: i64 = 0;
    var total_time: i64 = 0;

    // Warm-up run
    {
        var tree = try parse_to_tree(allocator, expr);
        defer tree.deinit(allocator);
        var result = try evaluate(allocator, &tree.root, &env);
        defer result.deinit();
    }

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        timer.reset();
        var tree = try parse_to_tree(allocator, expr);
        defer tree.deinit(allocator);
        var result = try evaluate(allocator, &tree.root, &env);
        defer result.deinit();

        const elapsed = timer.read();
        min_time = @min(min_time, @as(i64, @intCast(elapsed)));
        max_time = @max(max_time, @as(i64, @intCast(elapsed)));
        total_time += @as(i64, @intCast(elapsed));
    }

    return .{
        .min = min_time,
        .max = max_time,
        .avg = @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(iterations)),
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const iterations = 10000;

    std.debug.print("\nRunning Zig-only benchmarks...\n", .{});
    std.debug.print("Each expression evaluated {} times\n\n", .{iterations});

    for (test_expressions) |test_expr| {
        const result = try benchmarkExpression(allocator, test_expr.expr, iterations);
        std.debug.print("Expression: {s}\n", .{test_expr.expr});
        std.debug.print("  Min time: {d:.3} ns\n", .{@as(f64, @floatFromInt(result.min))});
        std.debug.print("  Max time: {d:.3} ns\n", .{@as(f64, @floatFromInt(result.max))});
        std.debug.print("  Avg time: {d:.3} ns\n\n", .{result.avg});
    }
}

test "run benchmarks" {
    try main();
}
