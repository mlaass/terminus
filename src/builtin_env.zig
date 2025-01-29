const std = @import("std");
const Value = @import("term_interpreter.zig").Value;
const InterpreterError = @import("term_interpreter.zig").InterpreterError;
const Allocator = std.mem.Allocator;
const calcUtf16LeLen = @import("std").unicode.calcUtf16LeLen;

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
pub fn coreInt(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;

    return Value{ .data = .{ .integer = try valueToInt(args[0]) } };
}

pub fn coreFloat(_: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;
    return Value{ .data = .{ .float = try valueToFloat(args[0]) } };
}

pub fn coreBool(_: Allocator, args: []const Value) InterpreterError!Value {
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
    const len = calcUtf16LeLen(str) catch return error.InvalidOperation;

    return Value{ .data = .{ .integer = @intCast(len) } };
}

fn strSubstring(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 3) return error.InvalidArgCount;

    const str = switch (args[0].data) {
        .string => |s| s,
        else => return error.TypeError,
    };

    const start = @as(usize, @intCast(args[1].data.integer));
    const end = @as(usize, @intCast(args[2].data.integer));

    if (start > end or end > str.len) return error.InvalidOperation;

    const result = try allocator.dupe(u8, str[start..end]);
    return Value{ .data = .{ .string = result }, .allocator = allocator };
}

fn strReplace(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 3) return error.InvalidArgCount;

    const str = switch (args[0].data) {
        .string => |s| s,
        else => return error.TypeError,
    };
    const old = switch (args[1].data) {
        .string => |s| s,
        else => return error.TypeError,
    };
    const new = switch (args[2].data) {
        .string => |s| s,
        else => return error.TypeError,
    };

    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    var i: usize = 0;
    while (i < str.len) {
        if (i + old.len <= str.len and std.mem.eql(u8, str[i .. i + old.len], old)) {
            try list.appendSlice(new);
            i += old.len;
        } else {
            try list.append(str[i]);
            i += 1;
        }
    }

    return Value{
        .data = .{ .string = try list.toOwnedSlice() },
        .allocator = allocator,
    };
}

fn strToUpper(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;

    const str = switch (args[0].data) {
        .string => |s| s,
        else => return error.TypeError,
    };

    var result = try allocator.alloc(u8, str.len);
    errdefer allocator.free(result);

    for (str, 0..) |c, i| {
        result[i] = std.ascii.toUpper(c);
    }

    return Value{ .data = .{ .string = result }, .allocator = allocator };
}

fn strToLower(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;

    const str = switch (args[0].data) {
        .string => |s| s,
        else => return error.TypeError,
    };

    var result = try allocator.alloc(u8, str.len);
    errdefer allocator.free(result);

    for (str, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }

    return Value{ .data = .{ .string = result }, .allocator = allocator };
}

fn strTrim(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 1) return error.InvalidArgCount;

    const str = switch (args[0].data) {
        .string => |s| s,
        else => return error.TypeError,
    };

    const trimmed = std.mem.trim(u8, str, " \t\r\n");
    const result = try allocator.dupe(u8, trimmed);

    return Value{ .data = .{ .string = result }, .allocator = allocator };
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

fn listConcat(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len < 1) return error.InvalidArgCount;

    var total_len: usize = 0;
    for (args) |arg| {
        const list = switch (arg.data) {
            .list => |l| l,
            else => return error.TypeError,
        };
        total_len += list.len;
    }

    var result = try allocator.alloc(Value, total_len);
    errdefer allocator.free(result);

    var index: usize = 0;
    for (args) |arg| {
        const list = arg.data.list;
        for (list) |item| {
            result[index] = try item.clone(allocator);
            index += 1;
        }
    }

    return Value{ .data = .{ .list = result }, .allocator = allocator };
}

fn listSlice(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 3) return error.InvalidArgCount;

    const list = switch (args[0].data) {
        .list => |l| l,
        else => return error.TypeError,
    };

    const start = @as(usize, @intCast(args[1].data.integer));
    const end = @as(usize, @intCast(args[2].data.integer));

    if (start > end or end > list.len) return error.InvalidOperation;

    var result = try allocator.alloc(Value, end - start);
    errdefer allocator.free(result);

    for (list[start..end], 0..) |item, i| {
        result[i] = try item.clone(allocator);
    }

    return Value{ .data = .{ .list = result }, .allocator = allocator };
}

fn listMap(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 2) return error.InvalidArgCount;

    const list = switch (args[0].data) {
        .list => |l| l,
        else => return error.TypeError,
    };

    const func = switch (args[1].data) {
        .function => |f| f,
        else => return error.TypeError,
    };

    var result = try allocator.alloc(Value, list.len);
    errdefer allocator.free(result);

    for (list, 0..) |item, i| {
        const mapped_item = try func(&[_]Value{item});
        result[i] = mapped_item;
    }

    return Value{ .data = .{ .list = result }, .allocator = allocator };
}

fn listFilter(allocator: Allocator, args: []const Value) InterpreterError!Value {
    if (args.len != 2) return error.InvalidArgCount;

    const list = switch (args[0].data) {
        .list => |l| l,
        else => return error.TypeError,
    };

    const predicate = switch (args[1].data) {
        .function => |f| f,
        else => return error.TypeError,
    };

    var temp_list = std.ArrayList(Value).init(allocator);
    defer temp_list.deinit();

    for (list) |item| {
        const result = try predicate(&[_]Value{item});
        const keep = switch (result.data) {
            .boolean => |b| b,
            else => return error.TypeError,
        };
        if (keep) {
            try temp_list.append(try item.clone(allocator));
        }
    }

    const result = try temp_list.toOwnedSlice();
    return Value{ .data = .{ .list = result }, .allocator = allocator };
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
    // core functions
    .{ "int", coreInt },
    .{ "float", coreFloat },
    .{ "bool", coreBool },
    // .{ "string", coreString },
    // .{ "date", coreDate },
    // .{ "list", coreList },
    // .{ "def", coreDef },
    //

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
    .{ "str.substring", strSubstring },
    .{ "str.replace", strReplace },
    .{ "str.toUpper", strToUpper },
    .{ "str.toLower", strToLower },
    .{ "str.trim", strTrim },
    // .{ "str.split", strSplit },
    // .{ "str.indexOf", strIndexOf },
    // .{ "str.contains", strContains },
    // .{ "str.startsWith", strStartsWith },
    // .{ "str.endsWith", strEndsWith },
    // .{ "str.regexMatch", strRegexMatch },
    // .{ "str.format", strFormat },

    // date stuff
    // use https://github.com/FObersteiner/zdt for dates, wait for 0.14.0 version of pydust to expose to python
    // .{ "date.addDays", dateAddDays },
    // .{ "date.addDays", dateAddDays },
    // .{ "date.addHours", dateAddHours },
    // .{ "date.addMinutes", dateAddMinutes },
    // .{ "date.addSeconds", dateAddSeconds },
    // .{ "date.dayOfWeek", dateDayOfWeek },
    // .{ "date.dayOfMonth", dateDayOfMonth },
    // .{ "date.dayOfYear", dateDayOfYear },
    // .{ "date.month", dateMonth },
    // .{ "date.year", dateYear },
    // .{ "date.week", dateWeek },
    // .{ "date.add", dateAdd },
    // .{ "date.sub", dateSub },

    // list stuff
    .{ "list.length", listLength },
    .{ "list.append", listAppend },
    .{ "list.concat", listConcat },
    .{ "list.get", listGet },
    .{ "list.slice", listSlice },
    .{ "list.map", listMap },
    .{ "list.filter", listFilter },
    // .{ "list.insert", listInsert },
    // .{ "list.head", listHead },
    // .{ "list.tail", listTail },
    // .{ "list.set", listSet },
    // .{ "list.remove", listRemove },
    // .{ "list.removeAt", listRemoveAt },
    // .{ "list.removeRange", listRemoveRange },
    // .{ "list.removeValue", listRemoveValue },
    // .{ "list.removeAll", listRemoveAll },
    // .{ "list.clear", listClear },
    // .{ "list.sort", listSort },
    // .{ "list.reverse", listReverse },
    // .{ "list.shuffle", listShuffle },
    // .{ "list.unique", listUnique },
    // .{ "list.contains", listContains },
    // .{ "list.indexOf", listIndexOf },
    // .{ "list.lastIndexOf", listLastIndexOf },
    // .{ "list.find", listFind },
    // .{ "list.findLast", listFindLast },
    // .{ "list.findAll", listFindAll },
    // .{ "list.findLastAll", listFindLastAll },
    // .{ "list.every", listEvery },
    // .{ "list.some", listSome },
    // .{ "list.forEach", listForEach },

    // Functional stuff
    // .{ "func.apply", funcApply},
    // .{ "func.bind", funcBind},
    // .{ "func.curry", funcCurry},
    // .{ "func.pipe", funcPipe},
    // .{ "func.compose", funcCompose},
    // .{ "func.memoize", funcMemoize},
    // .{ "func.throttle", funcThrottle},
    // .{ "func.debounce", funcDebounce},
    // .{ "func.once", funcOnce},
    // .{ "func.partial", funcPartial},
    // .{ "func.partialRight", funcPartialRight},
    // .{ "func.curryRight", funcCurryRight},
    // .{ "func.curryN", funcCurryN},
    // .{ "func.curryRightN", funcCurryRightN},
    // .{ "func.curryN", funcCurryN},
    // .{ "func.curryRightN", funcCurryRightN},
});

pub fn get(name: []const u8) ?*const fn (Allocator, []const Value) InterpreterError!Value {
    return functions.get(name) orelse constants.get(name);
}
