const std           = @import("std");
const tokenize_mod  = @import("tokenize.zig");

const Tokens = tokenize_mod.Tokens;

pub const Object_plain = struct {
    keys:   [][]const u8,
    values: []const Value
};

pub const Object_indexed = struct {
    ident_postfix:   u64,
    indexation:     *std.StringHashMap(usize),
    values:         []const Value
};

pub const Object = union(enum) {
    plain : Object_plain,
    indexed : Object_indexed
};

pub const Value = union(enum) {
    string      : []const u8,
    array       : []const Value,
    Object      : Object,
    integer     : i64,
    float       : f64,
    boolean     : bool,
    null_obj
};

pub const Json = struct {
    postfix_count:  u64,
    indexes:        std.StringHashMap(usize),
    value:          Value
};


pub const Errors = error {
    object_closing_brace,
    incorrect_value_token
};

const JsonError = std.mem.Allocator.Error || Errors || std.fmt.ParseFloatError || std.fmt.ParseIntError;
const ParseReturn = JsonError!struct { val: Value, tokens: []const Tokens };

pub fn parse_array(al: std.mem.Allocator, tokens: []const Tokens, root: *Json) ParseReturn {
    if(tokens.len == 0 or tokens[0] != .L_SQUARE_BRACE) {
        return Errors.incorrect_value_token;
    }

    var tokens_temp = tokens[1..];
    var array: std.ArrayList(Value) = .empty;
    errdefer array.deinit(al);
    var prev_comma = false;
    while(tokens_temp.len != 0) {
        switch(tokens_temp[0]) {
            .COMMA, .COLON => {
                return Errors.incorrect_value_token;
            },
            .R_SQUARE_BRACE => {
                if (prev_comma) {
                    return Errors.incorrect_value_token;
                }

                const result = try array.toOwnedSlice(al);
                return .{ .val = .{ .array = result }, .tokens = tokens_temp[1..] };
            },
            else => {
                const result = try parse_value(al, tokens_temp, root);
                try array.append(al, result.val);
                tokens_temp = result.tokens;
            }
        }

        prev_comma = false;

        if(tokens_temp.len == 0) {
            return Errors.incorrect_value_token;
        }

        switch(tokens_temp[0]) {
            .COMMA => {
                prev_comma = true;
                tokens_temp = tokens_temp[1..];
                continue;
            },
            .R_SQUARE_BRACE => {
                const result = try array.toOwnedSlice(al);
                return .{ .val = .{ .array = result }, .tokens = tokens_temp[1..] };
            },
            else => {
                return Errors.incorrect_value_token;
            }
        }
    }

    return Errors.incorrect_value_token;
}

pub fn parse_number(tokens: []const Tokens) ParseReturn {
    if (tokens.len == 0) {
        return Errors.incorrect_value_token;
    }

    if (tokens[0] != Tokens.NUMBER) {
        return Errors.incorrect_value_token;
    }

    if (std.fmt.parseInt(i64, tokens[0].NUMBER, 10)) |value| {
        return .{ .val = .{.integer = value }, .tokens = tokens[1..] };
    } else |_| {}

    const res_float = try std.fmt.parseFloat(f64, tokens[0].NUMBER);

    return .{ .val = .{ .float = res_float }, .tokens = tokens[1..] };
}

pub fn to_plain_obj(al: std.mem.Allocator, keys: std.ArrayList([]const u8), values : std.ArrayList(Value)) !Object {
    var keys_v = keys;
    var values_v = values;

    const obj_p: Object_plain = .{ .keys = try keys_v.toOwnedSlice(al), .values = try values_v.toOwnedSlice(al) };
    return .{ .plain = obj_p };
}

pub fn to_indexed_obj(al: std.mem.Allocator, root: *Json, values : std.ArrayList(Value)) !Object {
    var values_v = values;

    const obj_i: Object_indexed = .{ .values = try values_v.toOwnedSlice(al), .ident_postfix = root.*.postfix_count, .indexation = &root.*.indexes };
    return . { .indexed = obj_i };
}

pub fn check_for_key(keys: std.ArrayList([]const u8), key: []const u8) bool {
    for(keys.items) |entry| {
        if(std.mem.eql(u8, entry, key)) {
            return true;
        }
    }

    return false;
}

pub fn transform_key(al: std.mem.Allocator, postfix: usize, key: []const u8) ![]const u8 {
    var hex_buf: [20]u8 = undefined;
    const size = std.fmt.printInt(&hex_buf, postfix, 16, std.fmt.Case.upper, .{});

    const result = try al.alloc(u8, key.len + 1 + size);
    @memcpy(result[0..key.len], key);
    // insert a control code to remove possible conflict with a strings that ends with numbers
    result[key.len] = 0x01;
    @memcpy(result[key.len + 1..], hex_buf[0..size]);

    return result;
}

pub fn index_plain_objects(al: std.mem.Allocator, root: *Json, keys: std.ArrayList([]const u8)) !void {
    var i: usize = 0;
    const keys_entries = keys.items;

    while(i < keys_entries.len) : (i += 1) {
        const transformed_key = try transform_key(al, root.*.postfix_count, keys_entries[i]);
        try root.*.indexes.put(transformed_key, i);
    }

    return;
}

pub fn parse_object(al: std.mem.Allocator, tokens: []const Tokens, root: *Json) ParseReturn {
    if(tokens.len == 0) {
        return Errors.incorrect_value_token;
    }

    if(tokens[0] != .L_CURLY_BRACE) {
        return Errors.incorrect_value_token;
    }

    var tokens_temp = tokens[1..];
    var keys:     std.ArrayList([]const u8) = .empty;
    var values:   std.ArrayList(Value)      = .empty;
    errdefer keys.deinit(al);
    errdefer values.deinit(al);
    defer root.*.postfix_count += 1;

    var total_str_len_count: usize = 0;
    var prev_comma = false;
    while(tokens_temp.len != 0 and total_str_len_count < 512) {
        if (tokens_temp[0] == .R_CURLY_BRACE) {
            if(prev_comma) {
                return Errors.incorrect_value_token;
            }
            const value = try to_plain_obj(al, keys, values);
            return .{ .val = .{ .Object = value }, .tokens = tokens_temp[1..] };
        }

        prev_comma = false;

        if (tokens_temp[0] != .STR) {
            return Errors.incorrect_value_token;
        }

        const key = tokens_temp[0].STR;
        if(check_for_key(keys, key)) {
            return Errors.incorrect_value_token;
        }

        total_str_len_count += key.len;
        tokens_temp = tokens_temp[1..];
        if (tokens_temp.len == 0) {
            return Errors.incorrect_value_token;
        }

        if (tokens_temp[0] != .COLON) {
            return Errors.incorrect_value_token;
        }

        const result = try parse_value(al, tokens_temp[1..], root);
        tokens_temp = result.tokens;

        if (tokens_temp.len == 0) {
            return Errors.incorrect_value_token;
        }

        switch(tokens_temp[0]) {
            .COMMA => {
                prev_comma = true;
                tokens_temp = tokens_temp[1..];
            },
            .R_CURLY_BRACE => {
                const value = try to_plain_obj(al, keys, values);
                return .{ .val = .{ .Object = value }, .tokens = tokens_temp[1..] };
            },
            else => {
                return Errors.incorrect_value_token;
            }
        }

        try keys.append(al, key);
        try values.append(al, result.val);
    }

    if(tokens_temp.len == 0) {
        return Errors.incorrect_value_token;
    }

    try index_plain_objects(al, root, keys);

    while(tokens_temp.len != 0) {
        if (tokens_temp[0] == .R_SQUARE_BRACE) {
            const value = try to_indexed_obj(al, root, values);
            return .{ .val = .{ .Object = value }, .tokens = tokens_temp[1..] };
        }

        if (tokens_temp[0] != .STR) {
            return Errors.incorrect_value_token;
        }

        const key = try transform_key(al, root.*.postfix_count, tokens_temp[0].STR);
        if(root.*.indexes.contains(key)) {
            return Errors.incorrect_value_token;
        }

        total_str_len_count += key.len;
        tokens_temp = tokens_temp[1..];
        if (tokens_temp.len == 0) {
            return Errors.incorrect_value_token;
        }

        if (tokens_temp[0] != .COLON) {
            return Errors.incorrect_value_token;
        }

        const result = try parse_value(al, tokens_temp[1..], root);
        tokens_temp = result.tokens;

        try root.*.indexes.put(key, values.items.len - 1);
        try values.append(al, result.val);
    }

    return Errors.incorrect_value_token;
}

pub fn parse_value(al: std.mem.Allocator, tokens: []const Tokens, root: *Json) ParseReturn {
    if(tokens.len == 0) {
        return Errors.incorrect_value_token;
    }

    const tokens_temp = tokens;

    switch(tokens_temp[0]) {
        .L_CURLY_BRACE => {
            return try parse_object(al, tokens_temp, root);
        },
        .L_SQUARE_BRACE => {
            return try parse_array(al, tokens_temp, root);
        },
        .STR => {
            return .{ .val = .{ .string = tokens_temp[0].STR }, .tokens = tokens_temp[1..] };
        },
        .TRUE => {
            return .{ .val = .{ .boolean = true }, .tokens = tokens_temp[1..] };
        },
        .FALSE => {
            return .{ .val = .{ .boolean = false }, .tokens = tokens_temp[1..] };
        },
        .NULL => {
            return .{ .val = Value.null_obj, .tokens = tokens_temp[1..] };
        },
        .NUMBER => {
            return try parse_number(tokens_temp);
        },
        else => {
            return Errors.incorrect_value_token;
        }
    }
}

pub fn parse_syntax(al: std.mem.Allocator, tokens: []const Tokens) !Json {
    var root = Json {
        .postfix_count   = 0,
        .indexes        = std.StringHashMap(usize).init(al),
        .value          = Value.null_obj
    };

    const result = try parse_value(al, tokens, &root);
    if (result.tokens.len != 0) {
        return Errors.incorrect_value_token;
    }

    root.value = result.val;
    return root;
}

pub fn deinit_object(al: std.mem.Allocator, obj: Object) void {
    switch(obj) {
        .indexed => |ind| {
            for (ind.values) |val| {
                deinit_value(val);
            }
            al.free(ind.values);
        },
        .plain => |pl| {
            for (pl.keys) |key| {
                al.free(key);
            }

            for (pl.values) |val| {
                deinit_value(val);
            }

            al.free(pl.keys);
            al.free(pl.values);
        }
    }
}

pub fn deinit_value(al: std.mem.Allocator, value: Value) void {
    switch(value) {
        .string => |str| {
            al.free(str);
        },
        .array => |arr| {
            for (arr) |val| {
                deinit_value(val);
            }

            al.free(arr);
        },
        .Object => |obj| {
            al.free(obj);
        },
        else => {}
    }

}

pub fn deinit_json(al: std.mem.Allocator, json :Json) !void {
    deinit_value(al, json.value);
    json.indexes.deinit();
}

