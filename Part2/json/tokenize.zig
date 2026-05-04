const std = @import("std");

pub const Token = union(enum) {
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

pub fn tokenize_string(src: []const u8) !struct { str: []const u8, i: usize } {
    if (src.len == 0) {
        return .{ .str = &.{}, .i = 0 };
    }

    if (src[0] != '\"') {
        return Errors.illigal_character;
    }
    var i: usize = 1;

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
                    '\"', '\\', '/', 'b', 'f', 'n', 'r', 't' => {
                        i += 1;
                    },
                    'u' => {
                        i += 1;
                        if (i + 4 > src.len) return Errors.illigal_escape_sequence;

                        const high = std.fmt.parseUnsigned(u16, src[i..i + 4], 16)
                            catch return Errors.illigal_escape_sequence;
                        i += 4;

                        if (high >= 0xD800 and high <= 0xDBFF) {
                            if (i + 6 > src.len or src[i] != '\\' or src[i + 1] != 'u') {
                                return Errors.illigal_escape_sequence;
                            }
                            const low = std.fmt.parseUnsigned(u16, src[i + 2..i + 6], 16)
                                catch return Errors.illigal_escape_sequence;
                            if (low < 0xDC00 or low > 0xDFFF) return Errors.illigal_escape_sequence;
                            i += 6;
                        } else if (high >= 0xDC00 and high <= 0xDFFF) {
                            return Errors.illigal_escape_sequence;
                        }
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
                i += 1;
            }
        }
    }

    if (i == src.len or src[i] != '\"') {
        return Errors.illigal_character;
    }

    return .{ .str = src[1..i], .i = i + 1 };
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

pub fn tokenize_number(src: []const u8) ![]const u8 {
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

    return token;
}

pub fn tokenize(al: std.mem.Allocator, src: []const u8) ![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(al);

    var i: usize = 0;
    while(i < src.len) {
        switch(src[i]) {
            ' ', '\t', '\r', '\n' => {
                i += 1;
            },
            '{' => {
                try tokens.append(al, Token.L_CURLY_BRACE);
                i += 1;
            },
            '}' => {
                try tokens.append(al, Token.R_CURLY_BRACE);
                i += 1;
            },
            ',' => {
                try tokens.append(al, Token.COMMA);
                i += 1;
            },
            ':' => {
                try tokens.append(al, Token.COLON);
                i += 1;
            },
            't' => {
                try tokenize_literal("true", src[i..]);
                try tokens.append(al, Token.TRUE);
                i += 4;
            },
            'f' => {
                try tokenize_literal("false", src[i..]);
                try tokens.append(al, Token.FALSE);
                i += 5;
            },
            'n' => {
                try tokenize_literal("null", src[i..]);
                try tokens.append(al, Token.NULL);
                i += 4;
            },
            '\"' => {
                const result = try tokenize_string(src[i..]);
                try tokens.append(al, Token { .STR = result.str });
                i += result.i;
            },
            '[' => {
                try tokens.append(al, Token.L_SQUARE_BRACE);
                i += 1;
            },
            ']' => {
                try tokens.append(al, Token.R_SQUARE_BRACE);
                i += 1;
            },
            '-', '0'...'9' => {
                const num_token = Token { .NUMBER = try tokenize_number(src[i..])};
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

