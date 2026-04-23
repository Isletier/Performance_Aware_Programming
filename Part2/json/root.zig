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

pub fn tokenize_string(al: std.mem.Allocator, src: []const u8) ![]const u8 {
    var i: usize = 1;
    while (i < src.len and !(src[i] == '\"' and src[i - 1] != '\\')) {
        i += 1;
    }

    if (i == src.len) {
        return Errors.unrecognized_token;
    }

    var str = try al.alloc(u8, i);
    errdefer al.free(str);
    const len = i;
    i = 1;
    var k: usize = 0;
    while (i < len) {
        switch(src[i]) {
            0...31 => {
                return Errors.illigal_character;
            },
            '\\' => {
                i += 1;
                switch(src[i]) {
                    '\"' => {
                        str[k] = '\"';
                        i += 1;
                        k += 1;
                    },
                    '\\' => {
                        str[k] = '\\';
                        i += 1;
                        k += 1;
                    },
                    '/' => {
                        str[k] = '/';
                        i += 1;
                        k += 1;
                    },
                    'b' => {
                        str[k] = 'b';
                        i += 1;
                        k += 1;
                    },
                    'f' => {
                        str[k] = 0x0C;
                        i += 1;
                        k += 1;
                    },
                    'n' => {
                        str[k] = '\n';
                        i += 1;
                        k += 1;
                    },
                    'r' => {
                        str[k] = '\r';
                        i += 1;
                        k += 1;
                    },
                    't' => {
                        str[k] = '\t';
                        i += 1;
                        k += 1;
                    },
                    'u' => {
                        i += 1;
                        if ((i + 4) > len) {
                            return Errors.illigal_escape_sequence;
                        }

                        //this will allow, _ character, but who cares
                        str[k] = std.fmt.parseUnsigned(u8, src[i..(i + 2)], 16) catch {
                            return Errors.illigal_escape_sequence;
                        };
                        str[k + 1] = std.fmt.parseUnsigned(u8, src[(i + 2)..(i + 4)], 16) catch {
                            return Errors.illigal_escape_sequence;
                        };

                        i += 4;
                        k += 2;
                    },
                    else => {
                        return Errors.illigal_escape_sequence;
                    }
                }
            },
            else => {
                str[k] = src[i];
                i += 1;
                k += 1;
            }
        }
    }

    str = try al.realloc(str, k);
    return str;
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

    if (exponent.len < 3 or (exponent[i] != 'e' and exponent[i] != 'E')) {
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
            ' ' => {
                break;
            },
            '.' => {
                if (dot != src.len) {
                    return Errors.illigal_character;
                }

                dot = i;
            },
            else => {
                continue;
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
    const tokens = try al.alloc(Tokens, src.len);
    errdefer al.free(tokens);

    var i: usize = 0;
    var j: usize = 0;
    while(i < src.len) {
        switch(src[i]) {
            ' ', '\t', '\r', '\n' => {
                i += 1;
            },
            '{' => {
                tokens[j] = Tokens.L_CURLY_BRACE;
                i += 1;
                j += 1;
            },
            '}' => {
                tokens[j] = Tokens.R_CURLY_BRACE;
                i += 1;
                j += 1;
            },
            ',' => {
                tokens[j] = Tokens.COMMA;
                i += 1;
                j += 1;
            },
            ':' => {
                tokens[j] = Tokens.COLON;
                i += 1;
                j += 1;
            },
            't' => {
                try tokenize_literal("true", src[i..]);
                tokens[j] = Tokens.TRUE;
                i += 4;
                j += 1;
            },
            'f' => {
                try tokenize_literal("false", src[i..]);
                tokens[j] = Tokens.FALSE;
                i += 5;
                j += 1;
            },
            'n' => {
                try tokenize_literal("null", src[i..]);
                tokens[j] = Tokens.NULL;
                i += 4;
                j += 1;
            },
            '\"' => {
                tokens[j] = Tokens { .STR = try tokenize_string(al, src[i..]) };
                i += tokens[j].STR.len + 2;
                j += 1;
            },
            '[' => {
                tokens[j] = Tokens.L_SQUARE_BRACE;
                i += 1;
                j += 1;
            },
            ']' => {
                tokens[j] = Tokens.R_SQUARE_BRACE;
                i += 1;
                j += 1;
            },
            '-', '0'...'9' => {
                tokens[j] = Tokens { .NUMBER = try tokenize_number(al, src[i..])};
                i += tokens[j].NUMBER.len;
                j += 1;
            },
            else => {
                return Errors.unrecognized_token;
            }
        }

    }

    return tokens;
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
    defer al.free(out);
    try std.testing.expectEqualStrings("hello", out);
}

test "tokenize_string: escaped quote and backslash" {
    const al = std.testing.allocator;
    const src = "\"a\\\"b\\\\c\"";
    const out = try tokenize_string(al, src);
    defer al.free(out);
    try std.testing.expectEqualStrings("a\"b\\c", out);
}

test "tokenize_string: unicode escape \\u0041" {
    const al = std.testing.allocator;
    const src = "\"\\u0041\"";
    const out = try tokenize_string(al, src);
    defer al.free(out);
    try std.testing.expectEqualStrings("\x00\x41", out);
}

test "tokenize_string: unterminated returns error" {
    const al = std.testing.allocator;
    const src = "\"no closing quote";

    try std.testing.expectError(error.unrecognized_token, tokenize_string(al, src));
}

test "tokenize_string: control char is illegal" {
    const al = std.testing.allocator;
    const src = "\"bad\x01char\"";
    try std.testing.expectError(error.illigal_character, tokenize_string(al, src));
}

test "tokenize_string: empty string (just closing quote)" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"\"\"");
    defer al.free(out);
    try std.testing.expectEqualStrings("", out);
}

test "tokenize_string: forward slash escape \\/" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"a\\/b\"");
    defer al.free(out);
    try std.testing.expectEqualStrings("a/b", out);
}

test "tokenize_string: \\n escape should produce newline byte" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"line\\nbreak\"");
    defer al.free(out);
    try std.testing.expectEqualStrings("line\nbreak", out);
}

test "tokenize_string: \\t escape should produce tab byte" {
    const al = std.testing.allocator;
    const out = try tokenize_string(al, "\"a\\tb\"");
    defer al.free(out);
    try std.testing.expectEqualStrings("a\tb", out);
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

test "tokenize: comma separator" {
    const al = std.testing.allocator;
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

// --- adversarial tests below: each targets a specific suspected bug ---

test "tokenize: number inside array" {
    // Exercises tokenize_number stopping at ']'. Current impl init's i=src.len
    // in the scan loop so the loop never runs and the whole remainder is
    // passed to validate_number.
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
    // validate_number unconditionally bumps i to 1 before the leading-zero
    // check, so "0" reads number[1] out of bounds.
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
    // "05" is invalid JSON. The leading-zero check currently looks at
    // number[1] instead of number[0], so it lets this through.
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
    try std.testing.expectError(error.unrecognized_token, tokenize(al, "\"abc"));
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
    // Source span is 4 bytes, decoded length is 1. Outer tokenize advances
    // i by STR.len + 2 = 3, so the next iteration starts on the closing
    // quote instead of past it.
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
    // A is 'A' (one byte). The current impl parses the two hex pairs
    // independently and writes two bytes (0x00, 0x41).
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
