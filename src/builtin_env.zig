const std = @import("std");
const Value = @import("term_interpreter.zig").Value;
const InterpreterError = @import("term_interpreter.zig").InterpreterError;
const Allocator = std.mem.Allocator;

// Helper function to convert Value to f64
fn valueToFloat(value: Value) InterpreterError!f64 {
    return switch (value.data) {
        .integer => |i| @as(f64, @floatFromInt(i)),
        .float => |f| f,
        else => error.TypeError,
    };
}

// Helper function to convert Value to f64
fn valueToInt(value: Value) InterpreterError!i64 {
    return switch (value.data) {
        .integer => |i| i,
        .float => |f| @as(i64, @intFromFloat(f)),
        else => error.TypeError,
    };
}

// Math functions
pub fn builtin_int(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;

    return Value{ .data = .{ .integer = try valueToInt(args[0]) } };
}

pub fn builtin_float(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    return Value{ .data = .{ .float = try valueToFloat(args[0]) } };
}

pub fn builtin_bool(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    return Value{ .data = .{ .boolean = try valueToInt(args[0]) != 0 } };
}

pub fn min(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len < 1) return error.InvalidArgCount;

    // Keep track of both the float value for comparison and the original value
    var min_val = try valueToFloat(args[0]);
    var min_orig = args[0];

    for (args[1..]) |arg| {
        const val = try valueToFloat(arg);
        if (val < min_val) {
            min_val = val;
            min_orig = arg;
        }
    }

    return min_orig;
}

pub fn max(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len < 1) return error.InvalidArgCount;

    // Keep track of both the float value for comparison and the original value
    var max_val = try valueToFloat(args[0]);
    var max_orig = args[0];

    for (args[1..]) |arg| {
        const val = try valueToFloat(arg);
        if (val > max_val) {
            max_val = val;
            max_orig = arg;
        }
    }

    return max_orig;
}

pub fn log(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return Value{ .data = .{ .float = @log(x) } };
}

pub fn log2(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return Value{ .data = .{ .float = @log2(x) } };
}

pub fn log10(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return Value{ .data = .{ .float = @log10(x) } };
}

pub fn exp(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return Value{ .data = .{ .float = @exp(x) } };
}

pub fn sqrt(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return Value{ .data = .{ .float = @sqrt(x) } };
}

pub fn mean(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len == 0) return error.InvalidArgCount;

    var sum: f64 = 0;
    for (args) |arg| {
        sum += try valueToFloat(arg);
    }
    return Value{ .data = .{ .float = sum / @as(f64, @floatFromInt(args.len)) } };
}

pub fn abs(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return switch (args[0].data) {
        .integer => Value{ .data = .{ .integer = @intFromFloat(@fabs(x)) } },
        .float => Value{ .data = .{ .float = @fabs(x) } },
        else => error.TypeError,
    };
}

pub fn ceil(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return Value{ .data = .{ .float = @ceil(x) } };
}

pub fn floor(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const x = try valueToFloat(args[0]);
    return Value{ .data = .{ .float = @floor(x) } };
}

// String functions
fn strConcat(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len < 1) return error.InvalidArgCount;

    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();

    for (args) |arg| {
        switch (arg.data) {
            .string => |s| try buf.appendSlice(s),
            .integer => |i| {
                var temp_buf: [20]u8 = undefined;
                const str = std.fmt.bufPrint(&temp_buf, "{d}", .{i}) catch return error.OutOfMemory;
                try buf.appendSlice(str);
            },
            .float => |f| {
                var temp_buf: [32]u8 = undefined;
                const str = std.fmt.bufPrint(&temp_buf, "{d}", .{f}) catch return error.OutOfMemory;
                try buf.appendSlice(str);
            },
            .boolean => |b| {
                const str = if (b) "true" else "false";
                try buf.appendSlice(str);
            },
            else => return error.TypeError,
        }
    }

    const result = buf.toOwnedSlice() catch return error.OutOfMemory;
    return Value{ .data = .{ .string = result }, .allocator = allocator };
}

fn strLength(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const str = switch (args[0].data) {
        .string => |s| s,
        else => return error.TypeError,
    };
    return Value{ .data = .{ .integer = @intCast(str.len) } };
}

// Date functions
fn dateAddDays(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 2) return error.InvalidArgCount;
    const date_str = switch (args[0].data) {
        .date => |d| d,
        else => return error.TypeError,
    };

    // Parse date, add days, format result
    var buf: [64]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{s}", .{date_str}) catch return error.OutOfMemory;
    return Value{ .data = .{ .date = result } };
}

// List functions
fn listLength(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    const list = switch (args[0].data) {
        .list => |l| l,
        else => return error.TypeError,
    };
    return Value{ .data = .{ .integer = @intCast(list.len) } };
}

fn listGet(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 2) return error.InvalidArgCount;
    const list = switch (args[0].data) {
        .list => |l| l,
        else => return error.TypeError,
    };
    const index = @as(usize, @intCast(args[1].data.integer));
    if (index >= list.len) return error.InvalidOperation;

    // Clone the value to ensure proper memory management
    return list[index].clone(allocator);
}

fn listAppend(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 2) return error.InvalidArgCount;
    const list = switch (args[0].data) {
        .list => |l| l,
        else => return error.TypeError,
    };

    var new_list = try allocator.alloc(Value, list.len + 1);
    @memcpy(new_list[0..list.len], list);
    new_list[list.len] = args[1];

    return Value{ .data = .{ .list = new_list }, .allocator = allocator };
}

// Constants
pub const constants = std.ComptimeStringMap(Value, .{
    .{ "pi", Value{ .data = .{ .float = std.math.pi } } },
    .{ "e", Value{ .data = .{ .float = std.math.e } } },
    .{ "inf", Value{ .data = .{ .float = std.math.inf(f64) } } },
    .{ "tau", Value{ .data = .{ .float = std.math.tau } } },
    .{ "nan", Value{ .data = .{ .float = std.math.nan(f64) } } },
});

// Function map
pub const functions = std.ComptimeStringMap(*const fn (Allocator, []const Value) InterpreterError!Value, .{
    //types
    .{ "int", builtin_int },
    .{ "float", builtin_float },
    .{ "bool", builtin_bool },
    // .{ "string", builtin_string },
    // .{ "date", builtin_date },
    // .{ "list", builtin_list },
    // math stuff
    .{ "min", min },
    .{ "max", max },
    .{ "abs", abs },
    .{ "floor", floor },
    .{ "ceil", ceil },
    .{ "log", log },
    .{ "log2", log2 },
    // .{ "log1p", log1p },
    .{ "log10", log10 },
    .{ "exp", exp },
    .{ "sqrt", sqrt },
    // .{ "fsum", fsum },
    // .{ "gcd", gcd },
    // .{ "isqrt", isqrt },
    // .{ "cos", cos },
    // .{ "sin", sin },
    // .{ "tan", tan },
    // .{ "acos", acos },
    // .{ "asin", asin },
    // .{ "atan", atan },
    // .{ "degrees", degrees },
    // .{ "radians", radians },
    .{ "mean", mean },
    // .{ "fmean", fmean },
    // .{ "geometric_mean", geometric_mean },
    // .{ "median", median },
    // .{ "stdev", stdev },

    // string stuff
    // .{ "variance", variance },
    .{ "str.concat", strConcat },
    .{ "str.length", strLength },
    //     "str.substring": builtin_substring,
    //     "str.replace": builtin_replace,
    //     "str.toUpper": builtin_to_upper,
    //     "str.toLower": builtin_to_lower,
    //     "str.trim": builtin_trim,
    //     "str.split": builtin_split,
    //     "str.indexOf": builtin_index_of,
    //     "str.contains": builtin_contains,
    //     "str.startsWith": builtin_starts_with,
    //     "str.endsWith": builtin_ends_with,
    //     "str.regexMatch": builtin_regex_match,
    //     "str.format": builtin_format,
    // date stuff
    .{ "date.addDays", dateAddDays },
    //     "date.parse": parse_iso_date,
    //     "date.format": format_date,
    //     "date.addDays": add_days,
    //     "date.addHours": add_hours,
    //     "date.addMinutes": add_minutes,
    //     "date.addSeconds": add_seconds,
    //     "date.dayOfWeek": day_of_week,
    //     "date.dayOfMonth": day_of_month,
    //     "date.dayOfYear": day_of_year,
    //     "date.month": month_of_year,
    //     "date.year": year_of_date,
    //     "date.week": week_of_year,
    // list stuff
    .{ "list.length", listLength },
    .{ "list.append", listAppend },
    //     "list.concat": concat_lists,
    .{ "list.get", listGet },
    //     "list.put": list_put,
    //     "list.slice": slice_list,
    //     "list.map": list_map,
    //     "list.filter": list_filter,
    // .{ "apply", apply_function },
});

pub fn get(name: []const u8) ?*const fn (Allocator, []const Value) InterpreterError!Value {
    return functions.get(name);
}
