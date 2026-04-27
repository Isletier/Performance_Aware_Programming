const std = @import("std");

pub const Tokens = union(enum) {
    L_CURLY_BRACE,
    R_CURLY_BRACE,
    L_SQUARE_BRACE,
    R_SQUARE_BRACE,
    COMMA,
    COLON,
    STR:            []const u8,
    NUMBER:         []const u8,
    TRUE,
    FALSE,
    NULL
};

pub const Errors = error {
    unrecognized_token,
    illigal_character,
    illigal_escape_sequence
};

pub fn tokenize_literal(literal: []const u8, src: []const u8) !void {
    if (!std.mem.startsWith(u8, src, literal)) {
        return Errors.unrecognized_token;
    }

    return;
}

pub fn tokenize_string(al: std.mem.Allocator, src: []const u8) !struct { str: []const u8, i: usize } {
    if (src.len == 0) {
        return .{ .str = &.{}, .i = 0 };
    }

    if (src[0] != '\"') {
        return Errors.illigal_character;
    }
    var i: usize = 1;

    var str: std.ArrayList(u8) = .empty;
    errdefer str.deinit(al);
    while (i < src.len) {
        switch(src[i]) {
            0...31 => {
                return Errors.illigal_character;
            },
            '\\' => {
                i += 1;
                if (i == src.len) {
                    return Errors.illigal_character;
                }
                switch(src[i]) {
                    '\"' => {
                        try str.append(al, '\"');
                        i += 1;
                    },
                    '\\' => {
                        try str.append(al, '\\');
                        i += 1;
                    },
                    '/' => {
                        try str.append(al, '/');
                        i += 1;
                    },
                    'b' => {
                        try str.append(al, '\x08');
                        i += 1;
                    },
                    'f' => {
                        try str.append(al, 0x0C);
                        i += 1;
                    },
                    'n' => {
                        try str.append(al, '\n');
                        i += 1;
                    },
                    'r' => {
                        try str.append(al, '\r');
                        i += 1;
                    },
                    't' => {
                        try str.append(al, '\t');
                        i += 1;
                    },
                    'u' => {
                        i += 1;
                        if (i + 4 > src.len) return Errors.illigal_escape_sequence;

                        const high = std.fmt.parseUnsigned(u16, src[i..i + 4], 16)
                            catch return Errors.illigal_escape_sequence;
                        i += 4;

                        var cp: u21 = high;
                        if (high >= 0xD800 and high <= 0xDBFF) {
                            if (i + 6 > src.len or src[i] != '\\' or src[i + 1] != 'u') {
                                return Errors.illigal_escape_sequence;
                            }
                            const low = std.fmt.parseUnsigned(u16, src[i + 2..i + 6], 16)
                                catch return Errors.illigal_escape_sequence;
                            if (low < 0xDC00 or low > 0xDFFF) return Errors.illigal_escape_sequence;

                            const hi_bits: u21 = @as(u21, high) - 0xD800;
                            const lo_bits: u21 = @as(u21, low) - 0xDC00;
                            cp = 0x10000 + (hi_bits << 10) + lo_bits;
                            i += 6;
                        } else if (high >= 0xDC00 and high <= 0xDFFF) {
                            return Errors.illigal_escape_sequence;
                        }

                        var buf: [4]u8 = undefined;
                        const n = std.unicode.utf8Encode(cp, &buf)
                            catch return Errors.illigal_escape_sequence;
                        try str.appendSlice(al, buf[0..n]);
                    },
                    else => {
                        return Errors.illigal_escape_sequence;
                    }
                }
            },
            '\"' => {
                break;
            },
            else => {
                try str.append(al, src[i]);
                i += 1;
            }
        }
    }

    if (i == src.len or src[i] != '\"') {
        return Errors.illigal_character;
    }

    return .{.str = try str.toOwnedSlice(al), .i = i + 1};
}

pub fn validate_number(number: []const u8) bool {
    var i: usize = 0;
    if (number.len == 0) {
        return false;
    }

    if (number[i] == '+') {
        return false;
    }

    if (number[i] == '-') {
        if (number.len < 2) {
            return false;
        }

        i += 1;
    }

    if (number[i] == '0' and (i + 1) != number.len) {
        return false;
    }

    while(i != number.len) : (i += 1) {
        if(number[i] < '0' or number[i] > '9') {
            return false;
        }
    }

    return true;
}

pub fn validate_fraction(fraction: []const u8) bool {
    var i: usize = 0;
    if (fraction.len == 0) {
        return true;
    }

    if (fraction.len < 2 or fraction[0] != '.') {
        return false;
    }

    i += 1;
    while(i != fraction.len) : (i += 1) {
        if(fraction[i] < '0' or fraction[i] > '9') {
            return false;
        }
    }

    return true;
}

pub fn validate_exponent(exponent: []const u8) bool {
    var i: usize = 0;
    if (exponent.len == 0) {
        return true;
    }

    if (exponent.len == 1 or (exponent[i] != 'e' and exponent[i] != 'E')) {
        return false;
    }

    i += 1;
    if (exponent[i] == '+' or exponent[i] == '-') {
        if (exponent.len == 2) {
            return false;
        }

        i += 1;
    }

    while(i != exponent.len) : (i += 1) {
        if (exponent[i] < '0' or exponent[i] > '9') {
            return false;
        }
    }

    return true;
}

pub fn tokenize_number(al: std.mem.Allocator, src: []const u8) ![]const u8 {
    var i:          usize   = 0;
    var exp:        usize   = src.len;
    var dot:        usize   = src.len;
    while(i != src.len) : (i += 1) {
        switch (src[i]) {
            'e', 'E' => {
                if (exp != src.len) {
                    return Errors.illigal_character;
                }

                exp = i;
            },
            '+', '-', '0'...'9' => {
                continue;
            },
            '.' => {
                if (dot != src.len) {
                    return Errors.illigal_character;
                }

                dot = i;
            },
            else => {
                break;
            }
        }
    }

    var token = src[0..i];

    if(dot != src.len and dot > exp) {
        return Errors.illigal_character;
    }

    if(exp == src.len) {
        exp = token.len;
    }

    if(dot == src.len) {
        dot = exp;
    }

    const number = token[0..dot];
    const fraction = token[dot..exp];
    const exponent = token[exp..];

    if (!validate_number(number) or !validate_fraction(fraction) or !validate_exponent(exponent)) {
        return Errors.illigal_character;
    }

    const number_token = try al.alloc(u8, token.len);
    @memcpy(number_token, token);
    return number_token;
}

pub fn tokenize(al: std.mem.Allocator, src: []const u8) ![]Tokens {
    var tokens: std.ArrayList(Tokens) = .empty;
    errdefer tokens.deinit(al);

    var i: usize = 0;
    while(i < src.len) {
        switch(src[i]) {
            ' ', '\t', '\r', '\n' => {
                i += 1;
            },
            '{' => {
                try tokens.append(al, Tokens.L_CURLY_BRACE);
                i += 1;
            },
            '}' => {
                try tokens.append(al, Tokens.R_CURLY_BRACE);
                i += 1;
            },
            ',' => {
                try tokens.append(al, Tokens.COMMA);
                i += 1;
            },
            ':' => {
                try tokens.append(al, Tokens.COLON);
                i += 1;
            },
            't' => {
                try tokenize_literal("true", src[i..]);
                try tokens.append(al, Tokens.TRUE);
                i += 4;
            },
            'f' => {
                try tokenize_literal("false", src[i..]);
                try tokens.append(al, Tokens.FALSE);
                i += 5;
            },
            'n' => {
                try tokenize_literal("null", src[i..]);
                try tokens.append(al, Tokens.NULL);
                i += 4;
            },
            '\"' => {
                const result = try tokenize_string(al, src[i..]);
                try tokens.append(al, Tokens { .STR = result.str });
                i += result.i;
            },
            '[' => {
                try tokens.append(al, Tokens.L_SQUARE_BRACE);
                i += 1;
            },
            ']' => {
                try tokens.append(al, Tokens.R_SQUARE_BRACE);
                i += 1;
            },
            '-', '0'...'9' => {
                const num_token = Tokens { .NUMBER = try tokenize_number(al, src[i..])};
                i += num_token.NUMBER.len;
                try tokens.append(al, num_token);
            },
            else => {
                return Errors.unrecognized_token;
            }
        }

    }

    return try tokens.toOwnedSlice(al);
}


pub fn deinit_tokenize(al: std.mem.Allocator, tokens: []const Tokens) void {
    for (tokens) |token| {
        switch(token) {
//            Tokens.STR => |s| {
//                al.free(s);
//            },
            Tokens.NUMBER => |n| {
                al.free(n);
            },
            else => {}
        }
    }

    al.free(tokens);
}
