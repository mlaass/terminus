const std = @import("std");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");
const Environment = @import("interpreter_environment.zig").Environment;

// Global allocator for WASM
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Helper function to convert Zig string to JavaScript string pointer
fn zigStringToJs(str: []const u8) i32 {
    // Allocate space for string plus null terminator
    const result = allocator.alloc(u8, str.len + 1) catch return -1;
    @memcpy(result[0..str.len], str);
    result[str.len] = 0; // Add null terminator
    return @as(i32, @intCast(@intFromPtr(result.ptr)));
}

// Helper function to get string length (excluding null terminator)
export fn getStringLen(ptr: [*]const u8) i32 {
    var len: usize = 0;
    while (ptr[len] != 0 and len < 1024 * 1024) : (len += 1) {} // Add safety limit
    return @as(i32, @intCast(len));
}

// Helper function to write JSON string
fn writeJsonString(writer: anytype, str: []const u8) !void {
    try writer.writeByte('"');
    for (str) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
    try writer.writeByte('"');
}

// Export tokenize function
export fn tokenize(input_ptr: [*]const u8, len: i32) i32 {
    const input = input_ptr[0..@as(usize, @intCast(len))];
    const tokens = parser.tokenize(allocator, input) catch return -1;
    defer {
        for (tokens) |token| {
            allocator.free(token.value);
        }
        allocator.free(tokens);
    }

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();

    writer.writeAll("[") catch return -1;
    for (tokens, 0..) |token, i| {
        if (i > 0) writer.writeAll(",") catch return -1;
        writer.writeAll("{\"type\":\"") catch return -1;
        writer.writeAll(@tagName(token.type)) catch return -1;
        writer.writeAll("\",\"value\":") catch return -1;
        writeJsonString(writer, token.value) catch return -1;
        writer.writeAll("}") catch return -1;
    }
    writer.writeAll("]") catch return -1;

    return zigStringToJs(buf.items);
}

// Export shunting_yard function
export fn shuntingYard(input_ptr: [*]const u8, len: i32) i32 {
    const input = input_ptr[0..@as(usize, @intCast(len))];
    const tokens = parser.tokenize(allocator, input) catch return -1;
    defer {
        for (tokens) |token| {
            allocator.free(token.value);
        }
        allocator.free(tokens);
    }

    const rpn = parser.shunting_yard(allocator, tokens) catch return -1;
    defer {
        for (rpn) |*node| {
            node.deinit(allocator);
        }
        allocator.free(rpn);
    }

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();

    writer.writeAll("[") catch return -1;
    for (rpn, 0..) |node, i| {
        if (i > 0) writer.writeAll(",") catch return -1;
        writer.writeAll("{\"type\":\"") catch return -1;
        writer.writeAll(@tagName(node.type)) catch return -1;
        writer.writeByte('"') catch return -1;

        switch (node.type) {
            .literal_integer => writer.print(",\"value\":{d}", .{node.value.integer}) catch return -1,
            .literal_float => writer.print(",\"value\":{d}", .{node.value.float}) catch return -1,
            .literal_string => {
                writer.writeAll(",\"value\":") catch return -1;
                writeJsonString(writer, node.value.string) catch return -1;
            },
            .literal_date => {
                writer.writeAll(",\"value\":") catch return -1;
                writeJsonString(writer, node.value.date) catch return -1;
            },
            .identifier => {
                writer.writeAll(",\"value\":") catch return -1;
                writeJsonString(writer, node.value.identifier) catch return -1;
            },
            .binary_operator, .unary_operator => {
                writer.writeAll(",\"value\":") catch return -1;
                writeJsonString(writer, node.value.operator) catch return -1;
            },
            .function => {
                writer.writeAll(",\"name\":") catch return -1;
                writeJsonString(writer, node.value.function.name) catch return -1;
                writer.print(",\"argCount\":{d}", .{node.value.function.arg_count}) catch return -1;
            },
            .list => writer.print(",\"elementCount\":{d}", .{node.value.list.element_count}) catch return -1,
        }

        writer.writeByte('}') catch return -1;
    }
    writer.writeAll("]") catch return -1;

    return zigStringToJs(buf.items);
}

// Export parse_to_tree function
export fn parseToTree(input_ptr: [*]const u8, len: i32) i32 {
    const input = input_ptr[0..@as(usize, @intCast(len))];
    var tree = parser.parse_to_tree(allocator, input) catch return -1;
    defer tree.deinit(allocator);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();

    const serializeNode = struct {
        fn serialize(node: parser.Node, w: anytype) !void {
            try w.writeAll("{\"type\":\"");
            try w.writeAll(@tagName(node.type));
            try w.writeByte('"');

            switch (node.type) {
                .literal_integer => try w.print(",\"value\":{d}", .{node.value.integer}),
                .literal_float => try w.print(",\"value\":{d}", .{node.value.float}),
                .literal_string => {
                    try w.writeAll(",\"value\":");
                    try writeJsonString(w, node.value.string);
                },
                .literal_date => {
                    try w.writeAll(",\"value\":");
                    try writeJsonString(w, node.value.date);
                },
                .identifier => {
                    try w.writeAll(",\"value\":");
                    try writeJsonString(w, node.value.identifier);
                },
                .binary_operator, .unary_operator => {
                    try w.writeAll(",\"value\":");
                    try writeJsonString(w, node.value.operator);
                },
                .function => {
                    try w.writeAll(",\"name\":");
                    try writeJsonString(w, node.value.function.name);
                    try w.print(",\"argCount\":{d}", .{node.value.function.arg_count});
                },
                .list => try w.print(",\"elementCount\":{d}", .{node.value.list.element_count}),
            }

            if (node.args) |args| {
                try w.writeAll(",\"args\":[");
                for (args, 0..) |arg, i| {
                    if (i > 0) try w.writeByte(',');
                    try serialize(arg, w);
                }
                try w.writeByte(']');
            }

            try w.writeByte('}');
        }
    }.serialize;

    serializeNode(tree.root, writer) catch return -1;

    return zigStringToJs(buf.items);
}

// Export evaluate function
export fn evaluate(input_ptr: [*]const u8, len: i32) i32 {
    const input = input_ptr[0..@as(usize, @intCast(len))];
    var tree = parser.parse_to_tree(allocator, input) catch return -1;
    defer tree.deinit(allocator);

    var env = Environment.init(allocator, null);
    defer env.deinit();

    const result = interpreter.evaluate(allocator, &tree.root, &env) catch return -1;
    defer result.deinit();

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();

    writer.writeAll("{\"type\":\"") catch return -1;
    writer.writeAll(@tagName(result.data)) catch return -1;
    writer.writeAll("\",\"value\":") catch return -1;

    switch (result.data) {
        .integer => |v| writer.print("{d}", .{v}) catch return -1,
        .float => |v| writer.print("{d}", .{v}) catch return -1,
        .boolean => |v| writer.print("{}", .{v}) catch return -1,
        .string => |v| writeJsonString(writer, v) catch return -1,
        .date => |v| writeJsonString(writer, v) catch return -1,
        .list => |v| {
            writer.writeByte('[') catch return -1;
            for (v, 0..) |item, i| {
                if (i > 0) writer.writeByte(',') catch return -1;
                switch (item.data) {
                    .integer => |n| writer.print("{d}", .{n}) catch return -1,
                    .float => |n| writer.print("{d}", .{n}) catch return -1,
                    .boolean => |b| writer.print("{}", .{b}) catch return -1,
                    .string => |s| writeJsonString(writer, s) catch return -1,
                    .date => |d| {
                        writer.writeAll("\"d'") catch return -1;
                        writer.writeAll(d) catch return -1;
                        writer.writeAll("'\"") catch return -1;
                    },
                    else => writer.writeAll("null") catch return -1,
                }
            }
            writer.writeByte(']') catch return -1;
        },
        .function, .function_def => writer.writeAll("null") catch return -1,
    }

    writer.writeByte('}') catch return -1;

    return zigStringToJs(buf.items);
}

pub const os = struct {
    pub const system = struct {
        pub const fd_t = u8;
        pub const STDERR_FILENO = 1;
        pub const E = std.os.linux.E;

        pub fn getErrno(T: usize) E {
            _ = T;
            return .SUCCESS;
        }

        pub fn write(f: fd_t, ptr: [*]const u8, len: usize) usize {
            _ = ptr;
            _ = f;
            return len;
        }
    };
};
