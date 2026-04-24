const std = @import("std");

const print = std.debug.print;

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
            Tokens.STR => |s| {
                al.free(s);
            },
            Tokens.NUMBER => |n| {
                al.free(n);
            },
            else => {}
        }
    }

    al.free(tokens);
}

pub fn parse(src: []const u8) !void {
    _ = src;
    return;
}

test "tokenize_string: simple ascii" {
    const al = std.testing.allocator;
    const src = "\"hello\"";
    const out = try tokenize_string(al, src);
    defer al.free(out.str);
    try std.testing.expectEqualStrings("hello", out.str);
}

test "tokenize_string: escaped quote and backslash" {
    const al = std.testing.allocator;
    const src = "\"a\\\"b\\\\c\"";
    const out = try tokenize_string(al, src);
    defer al.free(out.str);
    try std.testing.expectEqualStrings("a\"b\\c", out.str);
}

test "tokenize_string: unterminated returns error" {
    const al = std.testing.allocator;
    const src = "\"no closing quote";

    try std.testing.expectError(error.illigal_character, tokenize_string(al, src));
}

test "tokenize_string: control char is illegal" {
    const al = std.testing.allocator;
    const src = "\"bad\x01char\"";
    try std.testing.expectError(error.illigal_character, tokenize_string(al, src));
}

test "tokenize_string: empty string (just closing quote)" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\"\"");
    defer al.free(out.str);
    try std.testing.expectEqualStrings("", out.str);
}

test "tokenize_string: forward slash escape \\/" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"a\\/b\"");
    defer al.free(out.str);
    try std.testing.expectEqualStrings("a/b", out.str);
}

test "tokenize_string: \\n escape should produce newline byte" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"line\\nbreak\"");
    defer al.free(out.str);
    try std.testing.expectEqualStrings("line\nbreak", out.str);
}

test "tokenize_string: \\t escape should produce tab byte" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"a\\tb\"");
    defer al.free(out.str);
    try std.testing.expectEqualStrings("a\tb", out.str);
}

test "tokenize_string: illegal escape returns error" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_escape_sequence, tokenize_string(al, "\"bad\\xescape\""));
}

test "tokenize_string: truncated \\u escape returns error" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_escape_sequence, tokenize_string(al, "\"\\u00\""));
}

test "tokenize_string: non-hex in \\u escape returns error" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_escape_sequence, tokenize_string(al, "\"\\uZZZZ\""));
}

test "tokenize_literal: exact match" {
    try tokenize_literal("true", "true");
}

test "tokenize_literal: match with trailing content" {
    try tokenize_literal("null", "null,1");
}

test "tokenize_literal: mismatch returns error" {
    try std.testing.expectError(error.unrecognized_token, tokenize_literal("true", "tru"));
}

test "tokenize_literal: wrong prefix returns error" {
    try std.testing.expectError(error.unrecognized_token, tokenize_literal("false", "fals1"));
}

fn expectTag(expected: std.meta.Tag(Tokens), actual: Tokens) !void {
    try std.testing.expectEqual(expected, std.meta.activeTag(actual));
}

test "tokenize: empty object" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{}");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.R_CURLY_BRACE, tokens[1]);
}

test "tokenize: empty array" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "[]");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.R_SQUARE_BRACE, tokens[1]);
}

test "tokenize: literal true/false/null" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "true false null");
    defer deinit_tokenize(al, tokens);
    try expectTag(.TRUE, tokens[0]);
    try expectTag(.FALSE, tokens[1]);
    try expectTag(.NULL, tokens[2]);
}

test "tokenize: key-value object" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"k\":true}");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try expectTag(.COLON, tokens[2]);
    try expectTag(.TRUE, tokens[3]);
    try expectTag(.R_CURLY_BRACE, tokens[4]);
}

test "tokenize: comma separator" { const al = std.testing.allocator;
    const tokens = try tokenize(al, "[true,false]");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.TRUE, tokens[1]);
    try expectTag(.COMMA, tokens[2]);
    try expectTag(.FALSE, tokens[3]);
    try expectTag(.R_SQUARE_BRACE, tokens[4]);
}

test "tokenize: number" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "42");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
}

test "tokenize: whitespace is ignored" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "  \t\n{\r\n}  ");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.R_CURLY_BRACE, tokens[1]);
}

test "tokenize: malformed literal returns error" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.unrecognized_token, tokenize(al, "trux"));
}


test "tokenize: number inside array" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "[42]");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.NUMBER, tokens[1]);
    try expectTag(.R_SQUARE_BRACE, tokens[2]);
}

test "tokenize: two numbers separated by comma" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1,2");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try expectTag(.COMMA, tokens[1]);
    try expectTag(.NUMBER, tokens[2]);
}

test "tokenize: lone zero is a valid number" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "0");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "0", tokens[0].NUMBER);
}

test "tokenize: negative integer" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "-7");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "-7", tokens[0].NUMBER);
}

test "tokenize: leading-zero integer is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "05"));
}

test "tokenize: fraction" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "3.14");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "3.14", tokens[0].NUMBER);
}

test "tokenize: exponent only" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1e10");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "1e10", tokens[0].NUMBER);
}

test "tokenize: fraction with signed exponent" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1.5e-3");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "1.5e-3", tokens[0].NUMBER);
}

test "tokenize: empty string literal" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\"");
    defer deinit_tokenize(al, tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqual(@as(usize, 0), tokens[0].STR.len);
}

test "tokenize: unterminated string errors" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "\"abc"));
}

test "tokenize: string is a single backslash" {
    // Source `"\\"` (4 chars) decodes to "\". The termination scan only
    // looks back one byte, so `\\"` is seen as "escaped quote, keep going"
    // and the string is reported unterminated.
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\\\\\"");
    defer deinit_tokenize(al, tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "\\", tokens[0].STR);
}

test "tokenize: string with newline escape" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\\n\"");
    defer deinit_tokenize(al, tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "\n", tokens[0].STR);
}

test "tokenize: escaped string followed by another token" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\\n\",\"x\"");
    defer deinit_tokenize(al, tokens);
    try expectTag(.STR, tokens[0]);
    try expectTag(.COMMA, tokens[1]);
    try expectTag(.STR, tokens[2]);
    try std.testing.expectEqualSlices(u8, "x", tokens[2].STR);
}

test "tokenize: raw control char in string is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "\"a\tb\""));
}

test "tokenize: \\u escape decodes to one code point" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\\u0041\"");
    defer deinit_tokenize(al, tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "A", tokens[0].STR);
}

test "tokenize: object with escaped key" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"\\n\":true}");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try expectTag(.COLON, tokens[2]);
    try expectTag(.TRUE, tokens[3]);
    try expectTag(.R_CURLY_BRACE, tokens[4]);
}

test "tokenize: nested array of numbers" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "[[1,2],[3]]");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.L_SQUARE_BRACE, tokens[1]);
    try expectTag(.NUMBER, tokens[2]);
    try expectTag(.COMMA, tokens[3]);
    try expectTag(.NUMBER, tokens[4]);
    try expectTag(.R_SQUARE_BRACE, tokens[5]);
    try expectTag(.COMMA, tokens[6]);
    try expectTag(.L_SQUARE_BRACE, tokens[7]);
    try expectTag(.NUMBER, tokens[8]);
    try expectTag(.R_SQUARE_BRACE, tokens[9]);
    try expectTag(.R_SQUARE_BRACE, tokens[10]);
}

test "tokenize: object with number value" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"n\":42}");
    defer deinit_tokenize(al, tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try expectTag(.COLON, tokens[2]);
    try expectTag(.NUMBER, tokens[3]);
    try expectTag(.R_CURLY_BRACE, tokens[4]);
}

test "tokenize_string: \\b escape produces backspace byte" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"x\\by\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "x\x08y", out.str);
}

test "tokenize_string: \\f escape produces form-feed byte" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"x\\fy\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "x\x0Cy", out.str);
}

test "tokenize_string: \\u00A9 encodes as UTF-8 0xC2 0xA9" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\u00A9\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\xC2\xA9", out.str);
}

test "tokenize_string: \\u0100 encodes as UTF-8 0xC4 0x80" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\u0100\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\xC4\x80", out.str);
}

test "tokenize_string: \\u0022 decodes to literal quote" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\u0022\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\"", out.str);
}

test "tokenize_string: trailing backslash at EOF" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize_string(al, "\"\\"));
}

test "tokenize: trailing backslash at EOF" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "\"\\"));
}

test "tokenize_string: backslash then EOF after opening quote" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize_string(al, "\"abc\\"));
}

test "tokenize: exponent without sign 0e5" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "0e5");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "0e5", tokens[0].NUMBER);
}

test "tokenize: exponent without sign capital 1E7" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1E7");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "1E7", tokens[0].NUMBER);
}

test "tokenize: fraction with unsigned exponent 1.5e9" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1.5e9");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "1.5e9", tokens[0].NUMBER);
}

test "tokenize: -0 is a valid number" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "-0");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "-0", tokens[0].NUMBER);
}

test "tokenize: leading-dot .5 is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.unrecognized_token, tokenize(al, ".5"));
}

test "tokenize: lone minus is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "-"));
}

test "tokenize: plus-prefixed number is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.unrecognized_token, tokenize(al, "+5"));
}

test "tokenize: number with double dot rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "1.2.3"));
}

test "tokenize: number with trailing dot rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "1."));
}

test "tokenize: number with bare exponent rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "1e"));
}

test "tokenize: empty input yields no tokens" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 0), tokens.len);
}

test "tokenize: only whitespace yields no tokens" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "   \t\n\r  ");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 0), tokens.len);
}

test "tokenize: true followed by string no space" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "true\"x\"");
    defer deinit_tokenize(al, tokens);
    try expectTag(.TRUE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try std.testing.expectEqualSlices(u8, "x", tokens[1].STR);
}

test "tokenize: string with many escapes mixed" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"a\\\"b\\\\c\\nd\\te\"");
    defer deinit_tokenize(al, tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "a\"b\\c\nd\te", tokens[0].STR);
}

test "tokenize: deeply nested arrays" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "[[[[[]]]]]");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 10), tokens.len);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.L_SQUARE_BRACE, tokens[4]);
    try expectTag(.R_SQUARE_BRACE, tokens[5]);
    try expectTag(.R_SQUARE_BRACE, tokens[9]);
}

test "tokenize: string containing only \\u0000" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\u0000\"");
    defer al.free(out.str);
    try std.testing.expectEqual(@as(usize, 1), out.str.len);
    try std.testing.expectEqual(@as(u8, 0), out.str[0]);
}

test "tokenize: negative fraction -0.25" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "-0.25");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "-0.25", tokens[0].NUMBER);
}

test "tokenize: object with array value" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"a\":[1,2]}");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 9), tokens.len);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try expectTag(.COLON, tokens[2]);
    try expectTag(.L_SQUARE_BRACE, tokens[3]);
    try expectTag(.NUMBER, tokens[4]);
    try expectTag(.COMMA, tokens[5]);
    try expectTag(.NUMBER, tokens[6]);
    try expectTag(.R_SQUARE_BRACE, tokens[7]);
    try expectTag(.R_CURLY_BRACE, tokens[8]);
}

test "tokenize_string: \\u0080 encodes to 0xC2 0x80" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\u0080\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\xC2\x80", out.str);
}

test "tokenize_string: \\u07FF encodes to 0xDF 0xBF" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\u07FF\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\xDF\xBF", out.str);
}

test "tokenize_string: \\u0800 encodes to 0xE0 0xA0 0x80" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\u0800\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\xE0\xA0\x80", out.str);
}

test "tokenize_string: \\uFFFF encodes to 0xEF 0xBF 0xBF" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\uFFFF\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\xEF\xBF\xBF", out.str);
}

test "tokenize_string: lowercase hex in \\u escape" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\u00a9\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\xC2\xA9", out.str);
}

test "tokenize_string: surrogate pair decodes to emoji" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\\uD83D\\uDE00\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "\xF0\x9F\x98\x80", out.str);
}

test "tokenize_string: raw UTF-8 multibyte passes through" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"caf\xC3\xA9\"");
    defer al.free(out.str);
    try std.testing.expectEqualSlices(u8, "caf\xC3\xA9", out.str);
}

test "tokenize_string: JSON-looking content inside string" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"[1,2]\"");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "[1,2]", tokens[0].STR);
}

test "tokenize_string: empty slice yields empty result" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "");
    try std.testing.expectEqual(@as(usize, 0), out.str.len);
    try std.testing.expectEqual(@as(usize, 0), out.i);
}

test "tokenize_string: single opening quote errors" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize_string(al, "\""));
}

test "tokenize: literal adjacent to number no whitespace" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "true42");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try expectTag(.TRUE, tokens[0]);
    try expectTag(.NUMBER, tokens[1]);
}

test "tokenize: number adjacent to literal no whitespace" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "42true");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try expectTag(.NUMBER, tokens[0]);
    try expectTag(.TRUE, tokens[1]);
}

test "tokenize: uppercase TRUE is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.unrecognized_token, tokenize(al, "TRUE"));
}

test "tokenize: raw UTF-8 outside string is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.unrecognized_token, tokenize(al, "\xC3\xA9"));
}

test "tokenize: negative zero with fraction" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "-0.0");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "-0.0", tokens[0].NUMBER);
}

test "tokenize: big object" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"a\":1,\"b\":2}");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 9), tokens.len);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try expectTag(.COLON, tokens[2]);
    try expectTag(.NUMBER, tokens[3]);
    try expectTag(.COMMA, tokens[4]);
    try expectTag(.STR, tokens[5]);
    try expectTag(.COLON, tokens[6]);
    try expectTag(.NUMBER, tokens[7]);
    try expectTag(.R_CURLY_BRACE, tokens[8]);
}

test "tokenize: array of five numbers" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "[1,2,3,4,5]");
    defer deinit_tokenize(al, tokens);
    try std.testing.expectEqual(@as(usize, 11), tokens.len);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.NUMBER, tokens[1]);
    try expectTag(.NUMBER, tokens[9]);
    try expectTag(.R_SQUARE_BRACE, tokens[10]);
}

test "tokenize: huge integer string passes" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "123456789012345678901234567890");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "123456789012345678901234567890", tokens[0].NUMBER);
}

test "tokenize: \\u followed by only 3 hex then quote" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_escape_sequence, tokenize(al, "\"\\u041\""));
}

test "tokenize: string with escaped unicode quote" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"a\\u0022b\"");
    defer deinit_tokenize(al, tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "a\"b", tokens[0].STR);
}

test "tokenize: lone high-surrogate is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_escape_sequence, tokenize(al, "\"\\uD800\""));
}

test "tokenize: lone low-surrogate is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_escape_sequence, tokenize(al, "\"\\uDC00\""));
}

test "tokenize: leading plus in exponent works" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "2.5E+10");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "2.5E+10", tokens[0].NUMBER);
}

test "tokenize: number 0.0 is valid" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "0.0");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "0.0", tokens[0].NUMBER);
}

test "tokenize: number 0.123e+45 is valid" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "0.123e+45");
    defer deinit_tokenize(al, tokens);
    try expectTag(.NUMBER, tokens[0]);
}

