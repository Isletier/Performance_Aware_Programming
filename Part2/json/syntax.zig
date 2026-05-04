const std           = @import("std");
const tokenize_mod  = @import("tokenize.zig");

const Token = tokenize_mod.Token;
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

pub const json_obj_key = struct {
    key:    []const u8,
    obj_id: u64
};

const json_object_context = struct {
    pub fn hash(self: json_object_context, key: json_obj_key) u64 {
        _ = self;
        var h = std.hash.Wyhash.init(0);
        h.update(key.key);
        const id_bytes = std.mem.asBytes(&key.obj_id);
        h.update(id_bytes);
        return h.final();
    }

    pub fn eql(self: json_object_context, a: json_obj_key, b: json_obj_key) bool {
        _ = self;
        return std.mem.eql(u8, a.key, b.key) and a.obj_id == b.obj_id;
    }
};

pub const json_object_map = std.HashMap(json_obj_key, u64, json_object_context, std.hash_map.default_max_load_percentage);

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

const ParseResult = JsonError!struct { val: Value, tokens: []const Token };

const ParseResultPlain = JsonError!struct { obj: Object_plain, tokens: []const Token, need_indexation: bool };

const ParseResultIndexed = JsonError!struct { obj: Object_indexed, tokens: []const Token };

pub fn unescape_string(al: std.mem.Allocator, raw: []const u8) ![]u8 {
    var str: std.ArrayList(u8) = .empty;
    errdefer str.deinit(al);
    var i: usize = 0;
    while (i < raw.len) {
        switch (raw[i]) {
            '\\' => {
                i += 1;
                switch (raw[i]) {
                    '\"' => { try str.append(al, '\"'); i += 1; },
                    '\\' => { try str.append(al, '\\'); i += 1; },
                    '/'  => { try str.append(al, '/');  i += 1; },
                    'b'  => { try str.append(al, '\x08'); i += 1; },
                    'f'  => { try str.append(al, 0x0C); i += 1; },
                    'n'  => { try str.append(al, '\n'); i += 1; },
                    'r'  => { try str.append(al, '\r'); i += 1; },
                    't'  => { try str.append(al, '\t'); i += 1; },
                    'u'  => {
                        i += 1;
                        const high = std.fmt.parseUnsigned(u16, raw[i..i + 4], 16)
                            catch return Errors.incorrect_value_token;
                        i += 4;

                        var cp: u21 = high;
                        if (high >= 0xD800 and high <= 0xDBFF) {
                            const low = std.fmt.parseUnsigned(u16, raw[i + 2..i + 6], 16)
                                catch return Errors.incorrect_value_token;
                            const hi_bits: u21 = @as(u21, high) - 0xD800;
                            const lo_bits: u21 = @as(u21, low) - 0xDC00;
                            cp = 0x10000 + (hi_bits << 10) + lo_bits;
                            i += 6;
                        }

                        var buf: [4]u8 = undefined;
                        const n = std.unicode.utf8Encode(cp, &buf)
                            catch return Errors.incorrect_value_token;
                        try str.appendSlice(al, buf[0..n]);
                    },
                    else => return Errors.incorrect_value_token,
                }
            },
            else => { try str.append(al, raw[i]); i += 1; },
        }
    }
    return try str.toOwnedSlice(al);
}


pub fn parse_array(al: std.mem.Allocator, tokens: []const Token, root: *Json) ParseResult {
    if(tokens.len == 0 or tokens[0] != .L_SQUARE_BRACE) {
        return Errors.incorrect_value_token;
    }

    var tokens_temp = tokens[1..];
    var array: std.ArrayList(Value) = .empty;
    errdefer deinit_array(al, array);
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

pub fn parse_number(tokens: []const Token) ParseResult {
    if (tokens.len == 0) {
        return Errors.incorrect_value_token;
    }

    if (tokens[0] != Token.NUMBER) {
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

pub fn index_plain_object(al: std.mem.Allocator, root: *Json, plain: Object_plain, id: usize) !void {
    var i: usize = 0;
    const keys_entries = plain.keys.items;


    while(i < keys_entries.len) : (i += 1) {
        root.*.indexes.put( .{ .key = keys_entries[i], .obj_id = id }, i) catch {
            break;
        };
    }

    while(i < keys_entries.len) : (i += 1) {
        al.free(keys_entries[i]);
    }

    return;
}

pub fn append_key(al: std.mem.Allocator, keys: *std.ArrayList([]const u8), token: Token) !usize {
    if (token != .STR) {
        return Errors.incorrect_value_token;
    }

    const current_key = try unescape_string(al, token.STR);
    errdefer al.free(current_key);

    if(check_for_key(keys.*, current_key)) {
        return Errors.incorrect_value_token;
    }
    try keys.append(al, current_key);

    return current_key.len;
}


pub fn append_key_root(al: std.mem.Allocator, root: *Json, token: Token, id: usize, pos: usize) !void {
    if (token != .STR) {
        return Errors.incorrect_value_token;
    }

    const current_key = try unescape_string(al, token.STR);
    errdefer al.free(current_key);

    const key: json_obj_key = .{ .key = current_key, .obj_id = id };
    if(root.*.indexes.contains(key)) {
        return Errors.incorrect_value_token;
    }

    try root.*.indexes.put(key, pos);

    return;
}

pub fn append_value(al: std.mem.Allocator, values: *std.ArrayList(Value), tokens: []const Token, root: *Json) ![]const Token {
    const result = try parse_value(al, tokens, root);
    errdefer deinit_value(al, result.val);

    try values.append(al, result.val);

    return result.tokens;
}

pub fn parse_plain(al: std.mem.Allocator, tokens: []const Token, root: *Json) ParseResultPlain {
    var tokens_temp = tokens[1..];
    var object_plain: Object_plain = .{ .keys = .empty, .values = .empty };
    errdefer deinit_plain(al, object_plain);

    var total_str_len_count: usize = 0;
    var prev_comma = false;
    while(tokens_temp.len != 0 and total_str_len_count < 512) {
        if (tokens_temp[0] == .R_CURLY_BRACE) {
            if(prev_comma) {
                return Errors.incorrect_value_token;
            }
            return .{ .obj = object_plain, .tokens = tokens_temp[1..], .need_indexation = false };
        }

        prev_comma = false;

        total_str_len_count += try append_key(al, &object_plain.keys, tokens_temp[0]);
        tokens_temp = tokens_temp[1..];

        if (tokens_temp.len == 0 or tokens_temp[0] != .COLON) {
            return Errors.incorrect_value_token;
        }
        tokens_temp = tokens_temp[1..];

        tokens_temp = try append_value(al, &object_plain.values, tokens_temp, root);

        if (tokens_temp.len == 0) {
            return Errors.incorrect_value_token;
        }

        switch(tokens_temp[0]) {
            .COMMA => {
                prev_comma = true;
                tokens_temp = tokens_temp[1..];
            },
            .R_CURLY_BRACE => {
                return .{ .obj = object_plain, .tokens = tokens_temp[1..], .need_indexation = false };
            },
            else => {
                return Errors.incorrect_value_token;
            }
        }
    }

    return .{ .obj = object_plain, .tokens = tokens_temp, .need_indexation = true };
}

pub fn parse_indexed(al: std.mem.Allocator, tokens: []const Token, root: *Json, plain: Object_plain) ParseResultIndexed {
    var tokens_temp = tokens;
    const id = root.postfix_count;
    defer root.postfix_count += 1;

    var plain_keys = plain.keys;
    defer plain_keys.deinit(al);

    var object: Object_indexed = .{
        .ident_postfix = id,
        .indexation = &root.indexes,
        .values = plain.values
    };
    errdefer deinit_indexed(al, object);

    try index_plain_object(al, root, plain, id);

    var prev_comma = false;

    while(tokens_temp.len != 0) {
        if (tokens_temp[0] == .R_CURLY_BRACE) {
            if(prev_comma) {
                return Errors.incorrect_value_token;
            }

            return .{ .obj = object, .tokens = tokens_temp[1..] };
        }
        prev_comma = false;

        try append_key_root(al, root, tokens_temp[0], id, object.values.items.len);
        tokens_temp = tokens_temp[1..];

        if (tokens_temp.len == 0 or tokens_temp[0] != .COLON) {
            return Errors.incorrect_value_token;
        }
        tokens_temp = tokens_temp[1..];

        tokens_temp = try append_value(al, &object.values, tokens_temp, root);
        if (tokens_temp.len == 0) {
            return Errors.incorrect_value_token;
        }

        switch(tokens_temp[0]) {
            .COMMA => {
                prev_comma = true;
                tokens_temp = tokens_temp[1..];
            },
            .R_CURLY_BRACE => {
                return .{ .obj = object, .tokens = tokens_temp[1..] };
            },
            else => {
                return Errors.incorrect_value_token;
            }
        }
    }

    return Errors.incorrect_value_token;
}


pub fn parse_object(al: std.mem.Allocator, tokens: []const Token, root: *Json) ParseResult {
    if(tokens.len == 0) {
        return Errors.incorrect_value_token;
    }

    if(tokens[0] != .L_CURLY_BRACE) {
        return Errors.incorrect_value_token;
    }

    const result_pl = try parse_plain(al, tokens, root);
    const tokens_temp = result_pl.tokens;

    if (!result_pl.need_indexation) {
        return .{ .val = .{ .Object = .{ .plain = result_pl.obj } }, .tokens = tokens_temp };
    }

    const result_ind = try parse_indexed(al, tokens_temp, root, result_pl.obj);

    return .{ .val = .{ .Object = .{ .indexed = result_ind.obj } }, .tokens = result_ind.tokens };
}

pub fn parse_value(al: std.mem.Allocator, tokens: []const Token, root: *Json) ParseResult {
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
        .STR => |raw| {
            const str = try unescape_string(al, raw);
            return .{ .val = .{ .string = str }, .tokens = tokens_temp[1..] };
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

pub fn parse_syntax(al: std.mem.Allocator, tokens: []const Token) !Json {
    var root = Json {
        .postfix_count   = 0,
        .indexes        = json_object_map.init(al),
        .value          = Value.null_obj
    };

    errdefer deinit_json(al, root);

    const result = try parse_value(al, tokens, &root);
    root.value = result.val;
    if (result.tokens.len != 0) {
        deinit_json(al, root);
        return Errors.incorrect_value_token;
    }

    return root;
}

pub fn deinit_plain(al: std.mem.Allocator, obj_: Object_plain) void {
    var obj = obj_;
    for (obj.keys.items) |key| {
        al.free(key);
    }
    for (obj.values.items) |val| {
        deinit_value(al, val);
    }
    obj.keys.deinit(al);
    obj.values.deinit(al);
}

pub fn deinit_indexed(al: std.mem.Allocator, obj_: Object_indexed) void {
    var obj = obj_;
    for (obj.values.items) |val| {
        deinit_value(al, val);
    }
    obj.values.deinit(al);
}

pub fn deinit_object(al: std.mem.Allocator, obj: Object) void {
    switch(obj) {
        .indexed => |ind| {
            deinit_indexed(al, ind);
        },
        .plain => |pl| {
            deinit_plain(al, pl);
        }
    }
}

pub fn deinit_array(al: std.mem.Allocator, arr_: std.ArrayList(Value)) void {
    var arr = arr_;
    for (arr.items) |val| {
        deinit_value(al, val);
    }

    arr.deinit(al);
}

pub fn deinit_value(al: std.mem.Allocator, value: Value) void {
    switch(value) {
        .string => |str| {
            al.free(str);
        },
        .array => |arr| {
            deinit_array(al, arr);
        },
        .Object => |obj| {
            deinit_object(al, obj);
        },
        else => {}
    }
}

pub fn deinit_json(al: std.mem.Allocator, json_: Json) void {
    var json = json_;
    deinit_value(al, json.value);
    var it = json.indexes.iterator();
    while (it.next()) |entry| {
        al.free(entry.key_ptr.key);
    }
    json.indexes.deinit();
}
