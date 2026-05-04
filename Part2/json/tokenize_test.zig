const std = @import("std");
const tokenize_mod = @import("tokenize.zig");

const Tokens = tokenize_mod.Token;
const tokenize = tokenize_mod.tokenize;
const tokenize_string = tokenize_mod.tokenize_string;
const tokenize_literal = tokenize_mod.tokenize_literal;
const deinit_tokenize = tokenize_mod.deinit_tokenize;

fn expectTag(expected: std.meta.Tag(Tokens), actual: Tokens) !void {
    try std.testing.expectEqual(expected, std.meta.activeTag(actual));
}

test "tokenize_string: simple ascii" {
    const src = "\"hello\"";
    const out = try tokenize_string(src);
    try std.testing.expectEqualStrings("hello", out.str);
}

test "tokenize_string: escaped quote and backslash" {
    const src = "\"a\\\"b\\\\c\"";
    const out = try tokenize_string(src);
    try std.testing.expectEqualStrings("a\\\"b\\\\c", out.str);
}

test "tokenize_string: unterminated returns error" {
    const src = "\"no closing quote";
    try std.testing.expectError(error.illigal_character, tokenize_string(src));
}

test "tokenize_string: control char is illegal" {
    const src = "\"bad\x01char\"";
    try std.testing.expectError(error.illigal_character, tokenize_string(src));
}

test "tokenize_string: empty string (just closing quote)" {
    const out = try tokenize_string("\"\"\"");
    try std.testing.expectEqualStrings("", out.str);
}

test "tokenize_string: forward slash escape \\/" {
    const out = try tokenize_string("\"a\\/b\"");
    try std.testing.expectEqualStrings("a\\/b", out.str);
}

test "tokenize_string: \\n escape should produce raw backslash-n" {
    const out = try tokenize_string("\"line\\nbreak\"");
    try std.testing.expectEqualStrings("line\\nbreak", out.str);
}

test "tokenize_string: \\t escape should produce raw backslash-t" {
    const out = try tokenize_string("\"a\\tb\"");
    try std.testing.expectEqualStrings("a\\tb", out.str);
}

test "tokenize_string: illegal escape returns error" {
    try std.testing.expectError(error.illigal_escape_sequence, tokenize_string("\"bad\\xescape\""));
}

test "tokenize_string: truncated \\u escape returns error" {
    try std.testing.expectError(error.illigal_escape_sequence, tokenize_string("\"\\u00\""));
}

test "tokenize_string: non-hex in \\u escape returns error" {
    try std.testing.expectError(error.illigal_escape_sequence, tokenize_string("\"\\uZZZZ\""));
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

test "tokenize: empty object" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{}");
    defer al.free(tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.R_CURLY_BRACE, tokens[1]);
}

test "tokenize: empty array" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "[]");
    defer al.free(tokens);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.R_SQUARE_BRACE, tokens[1]);
}

test "tokenize: literal true/false/null" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "true false null");
    defer al.free(tokens);
    try expectTag(.TRUE, tokens[0]);
    try expectTag(.FALSE, tokens[1]);
    try expectTag(.NULL, tokens[2]);
}

test "tokenize: key-value object" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"k\":true}");
    defer al.free(tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try expectTag(.COLON, tokens[2]);
    try expectTag(.TRUE, tokens[3]);
    try expectTag(.R_CURLY_BRACE, tokens[4]);
}

test "tokenize: comma separator" { const al = std.testing.allocator;
    const tokens = try tokenize(al, "[true,false]");
    defer al.free(tokens);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.TRUE, tokens[1]);
    try expectTag(.COMMA, tokens[2]);
    try expectTag(.FALSE, tokens[3]);
    try expectTag(.R_SQUARE_BRACE, tokens[4]);
}

test "tokenize: number" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "42");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
}

test "tokenize: whitespace is ignored" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "  \t\n{\r\n}  ");
    defer al.free(tokens);
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
    defer al.free(tokens);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.NUMBER, tokens[1]);
    try expectTag(.R_SQUARE_BRACE, tokens[2]);
}

test "tokenize: two numbers separated by comma" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1,2");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try expectTag(.COMMA, tokens[1]);
    try expectTag(.NUMBER, tokens[2]);
}

test "tokenize: lone zero is a valid number" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "0");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "0", tokens[0].NUMBER);
}

test "tokenize: negative integer" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "-7");
    defer al.free(tokens);
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
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "3.14", tokens[0].NUMBER);
}

test "tokenize: exponent only" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1e10");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "1e10", tokens[0].NUMBER);
}

test "tokenize: fraction with signed exponent" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1.5e-3");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "1.5e-3", tokens[0].NUMBER);
}

test "tokenize: empty string literal" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\"");
    defer al.free(tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqual(@as(usize, 0), tokens[0].STR.len);
}

test "tokenize: unterminated string errors" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "\"abc"));
}

test "tokenize: string is a single backslash" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\\\\\"");
    defer al.free(tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "\\\\", tokens[0].STR);
}

test "tokenize: string with newline escape" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\\n\"");
    defer al.free(tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "\\n", tokens[0].STR);
}

test "tokenize: escaped string followed by another token" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\\n\",\"x\"");
    defer al.free(tokens);
    try expectTag(.STR, tokens[0]);
    try expectTag(.COMMA, tokens[1]);
    try expectTag(.STR, tokens[2]);
    try std.testing.expectEqualSlices(u8, "\\n", tokens[0].STR);
    try std.testing.expectEqualSlices(u8, "x", tokens[2].STR);
}

test "tokenize: raw control char in string is rejected" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "\"a\tb\""));
}

test "tokenize: \\u escape raw slice" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"\\u0041\"");
    defer al.free(tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "\\u0041", tokens[0].STR);
}

test "tokenize: object with escaped key" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"\\n\":true}");
    defer al.free(tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try expectTag(.COLON, tokens[2]);
    try expectTag(.TRUE, tokens[3]);
    try expectTag(.R_CURLY_BRACE, tokens[4]);
}

test "tokenize: nested array of numbers" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "[[1,2],[3]]");
    defer al.free(tokens);
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
    defer al.free(tokens);
    try expectTag(.L_CURLY_BRACE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try expectTag(.COLON, tokens[2]);
    try expectTag(.NUMBER, tokens[3]);
    try expectTag(.R_CURLY_BRACE, tokens[4]);
}

test "tokenize_string: \\b escape produces raw backslash-b" {
    const out = try tokenize_string("\"x\\by\"");
    try std.testing.expectEqualSlices(u8, "x\\by", out.str);
}

test "tokenize_string: \\f escape produces raw backslash-f" {
    const out = try tokenize_string("\"x\\fy\"");
    try std.testing.expectEqualSlices(u8, "x\\fy", out.str);
}

test "tokenize_string: \\u00A9 raw slice" {
    const out = try tokenize_string("\"\\u00A9\"");
    try std.testing.expectEqualSlices(u8, "\\u00A9", out.str);
}

test "tokenize_string: \\u0100 raw slice" {
    const out = try tokenize_string("\"\\u0100\"");
    try std.testing.expectEqualSlices(u8, "\\u0100", out.str);
}

test "tokenize_string: \\u0022 raw slice" {
    const out = try tokenize_string("\"\\u0022\"");
    try std.testing.expectEqualSlices(u8, "\\u0022", out.str);
}

test "tokenize_string: trailing backslash at EOF" {
    try std.testing.expectError(error.illigal_character, tokenize_string("\"\\"));
}

test "tokenize: trailing backslash at EOF" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_character, tokenize(al, "\"\\"));
}

test "tokenize_string: backslash then EOF after opening quote" {
    try std.testing.expectError(error.illigal_character, tokenize_string("\"abc\\"));
}

test "tokenize: exponent without sign 0e5" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "0e5");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "0e5", tokens[0].NUMBER);
}

test "tokenize: exponent without sign capital 1E7" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1E7");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "1E7", tokens[0].NUMBER);
}

test "tokenize: fraction with unsigned exponent 1.5e9" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "1.5e9");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "1.5e9", tokens[0].NUMBER);
}

test "tokenize: -0 is a valid number" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "-0");
    defer al.free(tokens);
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
    defer al.free(tokens);
    try std.testing.expectEqual(@as(usize, 0), tokens.len);
}

test "tokenize: only whitespace yields no tokens" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "   \t\n\r  ");
    defer al.free(tokens);
    try std.testing.expectEqual(@as(usize, 0), tokens.len);
}

test "tokenize: true followed by string no space" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "true\"x\"");
    defer al.free(tokens);
    try expectTag(.TRUE, tokens[0]);
    try expectTag(.STR, tokens[1]);
    try std.testing.expectEqualSlices(u8, "x", tokens[1].STR);
}

test "tokenize: string with many escapes mixed" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"a\\\"b\\\\c\\nd\\te\"");
    defer al.free(tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "a\\\"b\\\\c\\nd\\te", tokens[0].STR);
}

test "tokenize: deeply nested arrays" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "[[[[[]]]]]");
    defer al.free(tokens);
    try std.testing.expectEqual(@as(usize, 10), tokens.len);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.L_SQUARE_BRACE, tokens[4]);
    try expectTag(.R_SQUARE_BRACE, tokens[5]);
    try expectTag(.R_SQUARE_BRACE, tokens[9]);
}

test "tokenize: string containing only \\u0000 raw" {
    const out = try tokenize_string("\"\\u0000\"");
    try std.testing.expectEqual(@as(usize, 6), out.str.len);
    try std.testing.expectEqualSlices(u8, "\\u0000", out.str);
}

test "tokenize: negative fraction -0.25" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "-0.25");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "-0.25", tokens[0].NUMBER);
}

test "tokenize: object with array value" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"a\":[1,2]}");
    defer al.free(tokens);
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

test "tokenize_string: \\u0080 raw slice" {
    const out = try tokenize_string("\"\\u0080\"");
    try std.testing.expectEqualSlices(u8, "\\u0080", out.str);
}

test "tokenize_string: \\u07FF raw slice" {
    const out = try tokenize_string("\"\\u07FF\"");
    try std.testing.expectEqualSlices(u8, "\\u07FF", out.str);
}

test "tokenize_string: \\u0800 raw slice" {
    const out = try tokenize_string("\"\\u0800\"");
    try std.testing.expectEqualSlices(u8, "\\u0800", out.str);
}

test "tokenize_string: \\uFFFF raw slice" {
    const out = try tokenize_string("\"\\uFFFF\"");
    try std.testing.expectEqualSlices(u8, "\\uFFFF", out.str);
}

test "tokenize_string: lowercase hex in \\u escape raw slice" {
    const out = try tokenize_string("\"\\u00a9\"");
    try std.testing.expectEqualSlices(u8, "\\u00a9", out.str);
}

test "tokenize_string: surrogate pair raw slice" {
    const out = try tokenize_string("\"\\uD83D\\uDE00\"");
    try std.testing.expectEqualSlices(u8, "\\uD83D\\uDE00", out.str);
}

test "tokenize_string: raw UTF-8 multibyte passes through" {
    const out = try tokenize_string("\"caf\xC3\xA9\"");
    try std.testing.expectEqualSlices(u8, "caf\xC3\xA9", out.str);
}

test "tokenize_string: JSON-looking content inside string" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"[1,2]\"");
    defer al.free(tokens);
    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "[1,2]", tokens[0].STR);
}

test "tokenize_string: empty slice yields empty result" {
    const out = try tokenize_string("");
    try std.testing.expectEqual(@as(usize, 0), out.str.len);
    try std.testing.expectEqual(@as(usize, 0), out.i);
}

test "tokenize_string: single opening quote errors" {
    try std.testing.expectError(error.illigal_character, tokenize_string("\""));
}

test "tokenize: literal adjacent to number no whitespace" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "true42");
    defer al.free(tokens);
    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try expectTag(.TRUE, tokens[0]);
    try expectTag(.NUMBER, tokens[1]);
}

test "tokenize: number adjacent to literal no whitespace" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "42true");
    defer al.free(tokens);
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
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "-0.0", tokens[0].NUMBER);
}

test "tokenize: big object" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "{\"a\":1,\"b\":2}");
    defer al.free(tokens);
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
    defer al.free(tokens);
    try std.testing.expectEqual(@as(usize, 11), tokens.len);
    try expectTag(.L_SQUARE_BRACE, tokens[0]);
    try expectTag(.NUMBER, tokens[1]);
    try expectTag(.NUMBER, tokens[9]);
    try expectTag(.R_SQUARE_BRACE, tokens[10]);
}

test "tokenize: huge integer string passes" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "123456789012345678901234567890");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "123456789012345678901234567890", tokens[0].NUMBER);
}

test "tokenize: \\u followed by only 3 hex then quote" {
    const al = std.testing.allocator;
    try std.testing.expectError(error.illigal_escape_sequence, tokenize(al, "\"\\u041\""));
}

test "tokenize: string with escaped unicode quote raw" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "\"a\\u0022b\"");
    defer al.free(tokens);
    try expectTag(.STR, tokens[0]);
    try std.testing.expectEqualSlices(u8, "a\\u0022b", tokens[0].STR);
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
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "2.5E+10", tokens[0].NUMBER);
}

test "tokenize: number 0.0 is valid" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "0.0");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
    try std.testing.expectEqualSlices(u8, "0.0", tokens[0].NUMBER);
}

test "tokenize: number 0.123e+45 is valid" {
    const al = std.testing.allocator;
    const tokens = try tokenize(al, "0.123e+45");
    defer al.free(tokens);
    try expectTag(.NUMBER, tokens[0]);
}

