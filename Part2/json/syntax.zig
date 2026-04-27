const std           = @import("std");
const tokenize_mod  = @import("tokenize.zig");

const Tokens = tokenize_mod.Tokens;

pub const Object_plain = struct {
    keys:   [][]const u8,
    values: []const Value
};

pub const Object_indexed = struct {
    ident_prefix:   u64,
    indexation:     *std.StringHashMap(usize),
    values:         []const Value
};

pub const Object = union(enum) {
    Object_plain,
    Object_indexed
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

const Value_t = std.meta.Tag(Value);

pub const RootObj = struct {
    prefix_count:   i64,
    indexes:        std.StringHashMap(usize),
    value:          Value
};


pub const Errors = error {
    object_closing_brace,
    incorrect_value_token
};


pub fn parse_array(al: std.mem.Allocator, tokens: []const Tokens, root: *RootObj) !struct { val: []const Value, tokens: []const Tokens } {
    if(tokens.len == 0 or tokens[0] != .L_SQUARE_BRACE) {
        return Errors.incorrect_value_token;
    }

    var tokens_temp = tokens[1..];
    var array: std.ArrayList(Value) = .empty;
    errdefer array.deinit(al);
    while(tokens_temp.len != 0) {
        switch(tokens_temp[0]) {
            .COMMA, .COLON => {
                return Errors.incorrect_value_token;
            },
            else => {
                const result = try parse_value(al, tokens, root);
                array.append(al, result.val);
                tokens_temp = result.tokens;
            }
        }

        if(tokens_temp.len == 0) {
            return Errors.incorrect_value_token;
        }

        if(tokens_temp[0] == .R_SQUARE_BRACE) {
            const result = try array.toOwnedSlice(al);
            return .{ .val = result, .tokens = tokens_temp[1..] };
        }

        if(tokens_temp[0] != .COMMA) {
            return Errors.incorrect_value_token;
        }
    }

    return Errors.incorrect_value_token;
}

pub fn parse_number(tokens: []const Tokens) !struct { val: Value, tokens: []const Tokens } {
    if (tokens.len == 0) {
        return Errors.incorrect_value_token;
    }

    const res_int = std.fmt.parseInt(i64, tokens[0], 10);
    if (res_int) |value| {
        return .{ .val = value, .tokens = tokens[1..] };
    }

    const res_float = try std.fmt.parseFloat(f64, tokens[0]);

    return .{ .val = res_float, .tokens = tokens[1..] };
}

pub fn to_plain_obj(al: std.mem.Allocator, keys: std.ArrayList([]const u8), values : std.ArrayList(Value)) !Object_plain {
    return .{ .keys = try keys.toOwnedSlice(al), .values = try values.toOwnedSlice(al) };
}

pub fn check_for_key(keys: std.ArrayList([]const u8), key: []const u8) bool {
    for(keys) |entry| {
        if(entry == key) {
            return true;
        }
    }

    return false;
}

pub fn index_plain_objects(al: std.mem.Allocator, root: *RootObj, keys: std.ArrayList([]const u8), values : std.ArrayList(Value)) !void {
    var i = 0;
    const keys_entries = keys.items;
    const values_entries = values.items;

    al.realloc(, new_n: usize)
    const str = try std.fmt.printInt(buf, root.*.prefix_count, 16);

    while(i < keys_entries.len) : (i += 1) {
        
        try root.*.indexes.put(keys_entries[i], values_entries[i]);
    }

    
}

pub fn parse_object(al: std.mem.Allocator, tokens: []const Tokens, root: *RootObj) !struct { val: Object, tokens: []const Tokens } {
    if(tokens.len == 0) {
        return Errors.incorrect_value_token;
    }

    if(tokens[0] != .L_CURLY_BRACERS) {
        return Errors.incorrect_value_token;
    }

    const tokens_temp = tokens[1..];
    const keys:     std.ArrayList([]const u8) = .empty;
    const values:   std.ArrayList(Value) = .empty;
    errdefer keys.deinit(al);
    errdefer values.deinit(al);

    var total_str_len_count = 0;
    while(tokens_temp.len != 0 and total_str_len_count < 512) {
        if (tokens_temp[0] == .R_SQUARE_BRACES) {
            const value = to_plain_obj(al, keys, values);
            return .{ .val = value, .tokens = tokens_temp[1..] };
        }

        if (tok`    ens_temp[0] != .STR) {
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

        try keys.append(al, key);
        try values.append(al, result.val);
    }

    if(tokens_temp.len == 0) {
        return Errors.incorrect_value_token;
    }

}

pub fn parse_value(al: std.mem.Allocator, tokens: []const Tokens, root: *RootObj) !struct { val: Value, tokens: []const Tokens } {
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
            return .{ .val = tokens_temp[0].STR, .tokens = tokens_temp[1..] };
        },
        .TRUE => {
            return .{ .val = true, .tokens = tokens_temp[1..] };
        },
        .FALSE => {
            return .{ .val = false, .tokens = tokens_temp[1..] };
        },
        .NULL => {
            return .{ .val = Value.null_obj, .tokens = tokens_temp[1..] };
        },
        .NUMBER => {
            return try parse_number();
        },
    }
}

pub fn parse_syntax(al: std.mem.Allocator, tokens: []const Tokens) !RootObj {
    if (tokens[0] == Tokens.L_CURLY_BRACE) {
        if (tokens[tokens.len - 1] != Tokens.R_CURLY_BRACE) {
            return Errors.object_closing_brace;
        }

        tokens = tokens[1..(tokens.len - 1)];
    }

    var value_stack: std.ArrayList(Value_t) = .empty;
    errdefer value_stack.deinit(al);

    const root = RootObj {
        .prefix_count   = 0,
        .indexes        = std.StringHashMap(Value).init(al),
        .value          = .empty
    };

    return try parse_value(al, tokens, root);
}

