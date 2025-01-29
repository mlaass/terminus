const std = @import("std");
const Value = @import("interpreter.zig").Value;
const builtin = @import("interpreter_builtin.zig");
const Allocator = std.mem.Allocator;

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
        } else if (builtin.constants.get(name)) |constant| {
            return constant;
        } else {
            return null;
        }
    }

    pub fn put(self: *Environment, name: []const u8, value: Value) !void {
        try self.store.put(name, value);
    }
};
