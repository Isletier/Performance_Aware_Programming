const std           = @import("std");
const tokenize_mod  = @import("tokenize.zig");

const Tokens = tokenize_mod.Tokens;
const deinit_tokenize = tokenize_mod.deinit_tokenize;

pub const Object_plain = struct {
    keys:   std.ArrayList([]const u8),
    values: std.ArrayList(Value) 
};

pub const Object_indexed = struct {
    ident_postfix:  u64,
    indexation:     *json_object_map,
    values:         std.ArrayList(Value) 
};

pub const Object = union(enum) {
    plain   : Object_plain,
    indexed : Object_indexed
};

pub const Value = union(enum) {
    string      : []const u8,
    array       : std.ArrayList(Value),
    Object      : Object,
    integer     : i64,
    float       : f64,
    boolean     : bool,
    null_obj
};

pub const json_object_key = struct {
    key:    []const u8,
    obj_id: u64
};

const json_object_context = struct {
    pub fn hash(self: json_object_context, key: json_object_key) u64 {
        _ = self;
        var h = std.hash.Wyhash.init(0);
        h.update(key.key);
        const id_bytes = std.mem.asBytes(&key.obj_id);
        h.update(id_bytes);
        return h.final();
    }

    pub fn eql(self: json_object_context, a: json_object_key, b: json_object_key) bool {
        _ = self;
        return std.mem.eql(u8, a.key, b.key) and a.obj_id == b.obj_id;
    }
};

pub const json_object_map = std.HashMap(json_object_key, u64, json_object_context, std.hash_map.default_max_load_percentage);

pub const Json = struct {
    postfix_count:  u64,
    indexes:        json_object_map,
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
    errdefer deinit_array(al, array, true);
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

                return .{ .val = .{ .array = array }, .tokens = tokens_temp[1..] };
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
                return .{ .val = .{ .array = array }, .tokens = tokens_temp[1..] };
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

pub fn check_for_key(keys: std.ArrayList([]const u8), key: []const u8) bool {
    for(keys.items) |entry| {
        if(std.mem.eql(u8, entry, key)) {
            return true;
        }
    }

    return false;
}

pub fn index_plain_object(root: *Json, plain: Object_plain) !void {
    var i: usize = 0;
    const keys_entries = plain.keys.items;

    while(i < keys_entries.len) : (i += 1) {
        try root.*.indexes.put( .{ .key = keys_entries[i], .obj_id = root.*.postfix_count }, i);
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
    var object:      Object = .{ .plain = .{ .keys = .empty, .values = .empty } };
    errdefer deinit_object(al, object, true);
    defer root.*.postfix_count += 1;

    var total_str_len_count: usize = 0;
    var prev_comma = false;
    while(tokens_temp.len != 0 and total_str_len_count < 512) {
        if (tokens_temp[0] == .R_CURLY_BRACE) {
            if(prev_comma) {
                return Errors.incorrect_value_token;
            }
            return .{ .val = .{ .Object = object }, .tokens = tokens_temp[1..] };
        }

        prev_comma = false;

        if (tokens_temp[0] != .STR) {
            return Errors.incorrect_value_token;
        }

        const key = tokens_temp[0].STR;
        if(check_for_key(object.plain.keys, key)) {
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
                return .{ .val = .{ .Object = object }, .tokens = tokens_temp[1..] };
            },
            else => {
                return Errors.incorrect_value_token;
            }
        }

        try object.plain.keys.append(al, key);
        try object.plain.values.append(al, result.val);
    }

    if(tokens_temp.len == 0) {
        return Errors.incorrect_value_token;
    }

    try index_plain_object(root, object.plain);

    object = .{ .indexed = .{
        .ident_postfix = root.*.postfix_count,
        .indexation = &root.*.indexes,
        .values = object.plain.values
    }};

    while(tokens_temp.len != 0) {
        if (tokens_temp[0] == .R_SQUARE_BRACE) {
            return .{ .val = .{ .Object = object }, .tokens = tokens_temp[1..] };
        }

        if (tokens_temp[0] != .STR) {
            return Errors.incorrect_value_token;
        }

        const key: json_object_key = .{ .key = tokens_temp[0].STR, .obj_id = root.*.postfix_count };
        if(root.*.indexes.contains(key)) {
            return Errors.incorrect_value_token;
        }

        tokens_temp = tokens_temp[1..];
        if (tokens_temp.len == 0) {
            return Errors.incorrect_value_token;
        }

        if (tokens_temp[0] != .COLON) {
            return Errors.incorrect_value_token;
        }

        const result = try parse_value(al, tokens_temp[1..], root);
        tokens_temp = result.tokens;

        try root.*.indexes.put(key, object.indexed.values.items.len - 1);
        try object.indexed.values.append(al, result.val);
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
        .indexes        = json_object_map.init(al),
        .value          = Value.null_obj
    };

    errdefer deinit_tokenize(al, tokens);
    errdefer root.indexes.deinit();

    const result = try parse_value(al, tokens, &root);
    root.value = result.val;
    if (result.tokens.len != 0) {
        deinit_json(al, root);
        return Errors.incorrect_value_token;
    }

    return root;
}

pub fn deinit_object(al: std.mem.Allocator, obj_: Object, ignore_string: bool) void {
    var obj = obj_;
    switch(obj) {
        .indexed => |*ind| {
            for (ind.values.items) |val| {
                deinit_value(al, val, ignore_string);
            }
            ind.values.deinit(al);
        },
        .plain => |*pl| {
            if(!ignore_string) {
                for (pl.keys.items) |key| {
                    al.free(key);
                }
            }

            for (pl.values.items) |val| {
                deinit_value(al, val, ignore_string);
            }

            pl.keys.deinit(al);
            pl.values.deinit(al);
        }
    }
}

pub fn deinit_array(al: std.mem.Allocator, arr_: std.ArrayList(Value), ignore_string: bool) void {
    var arr = arr_;
    for (arr.items) |val| {
        deinit_value(al, val, ignore_string);
    }

    arr.deinit(al);
}

pub fn deinit_value(al: std.mem.Allocator, value: Value, ignore_string: bool) void {
    switch(value) {
        .string => |str| {
            if(!ignore_string) {
                al.free(str);
            }
        },
        .array => |arr| {
            deinit_array(al, arr, ignore_string);
        },
        .Object => |obj| {
            deinit_object(al, obj, ignore_string);
        },
        else => {}
    }

}

pub fn deinit_json(al: std.mem.Allocator, json_: Json) void {
    var json = json_;
    deinit_value(al, json.value, false);
    var it = json.indexes.iterator();
    while (it.next()) |entry| {
        al.free(entry.key_ptr.key);
    }
    json.indexes.deinit();
}

