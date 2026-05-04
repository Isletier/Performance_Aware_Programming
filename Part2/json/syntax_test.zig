const std = @import("std");
const syntax_mod = @import("syntax.zig");
const tokenize_mod = @import("tokenize.zig");

const Tokens = tokenize_mod.Token;
const Value = syntax_mod.Value;
const Object = syntax_mod.Object;
const Object_plain = syntax_mod.Object_plain;
const Object_indexed = syntax_mod.Object_indexed;
const Json = syntax_mod.Json;
const json_object_map = syntax_mod.json_object_map;

fn make_root(al: std.mem.Allocator) Json {
    return Json{
        .postfix_count = 0,
        .indexes = json_object_map.init(al),
        .value = .null_obj,
    };
}

// ---------- parse_value: terminal tokens ----------

test "parse_value: empty token slice errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens: []const Tokens = &.{};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_value(al, tokens, &root));
}

test "parse_value: single STR token" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ Tokens{ .STR = "hello" } };
    const out = try syntax_mod.parse_value(al, &tokens, &root);
    defer syntax_mod.deinit_value(al, out.val);
    try std.testing.expectEqual(std.meta.Tag(Value).string, std.meta.activeTag(out.val));
    try std.testing.expectEqualSlices(u8, "hello", out.val.string);
    try std.testing.expectEqual(@as(usize, 0), out.tokens.len);
}

test "parse_value: TRUE token" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.TRUE};
    const out = try syntax_mod.parse_value(al, &tokens, &root);
    try std.testing.expectEqual(std.meta.Tag(Value).boolean, std.meta.activeTag(out.val));
    try std.testing.expectEqual(true, out.val.boolean);
}

test "parse_value: FALSE token" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.FALSE};
    const out = try syntax_mod.parse_value(al, &tokens, &root);
    try std.testing.expectEqual(std.meta.Tag(Value).boolean, std.meta.activeTag(out.val));
    try std.testing.expectEqual(false, out.val.boolean);
}

test "parse_value: NULL token" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.NULL};
    const out = try syntax_mod.parse_value(al, &tokens, &root);
    try std.testing.expectEqual(std.meta.Tag(Value).null_obj, std.meta.activeTag(out.val));
}

test "parse_value: NUMBER int token" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ Tokens{ .NUMBER = "42" } };
    const out = try syntax_mod.parse_value(al, &tokens, &root);
    try std.testing.expectEqual(std.meta.Tag(Value).integer, std.meta.activeTag(out.val));
    try std.testing.expectEqual(@as(i64, 42), out.val.integer);
}

test "parse_value: NUMBER negative int token" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ Tokens{ .NUMBER = "-7" } };
    const out = try syntax_mod.parse_value(al, &tokens, &root);
    try std.testing.expectEqual(std.meta.Tag(Value).integer, std.meta.activeTag(out.val));
    try std.testing.expectEqual(@as(i64, -7), out.val.integer);
}

test "parse_value: NUMBER float token" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ Tokens{ .NUMBER = "3.14" } };
    const out = try syntax_mod.parse_value(al, &tokens, &root);
    try std.testing.expectEqual(std.meta.Tag(Value).float, std.meta.activeTag(out.val));
}

test "parse_value: COMMA token errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.COMMA};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_value(al, &tokens, &root));
}

test "parse_value: COLON token errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.COLON};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_value(al, &tokens, &root));
}

test "parse_value: R_SQUARE_BRACE alone errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.R_SQUARE_BRACE};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_value(al, &tokens, &root));
}

test "parse_value: R_CURLY_BRACE alone errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.R_CURLY_BRACE};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_value(al, &tokens, &root));
}

test "parse_value: leftover tokens passed through" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .TRUE, .COMMA, .FALSE };
    const out = try syntax_mod.parse_value(al, &tokens, &root);
    try std.testing.expectEqual(@as(usize, 2), out.tokens.len);
}

// ---------- parse_array ----------

test "parse_array: empty token slice errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens: []const Tokens = &.{};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_array(al, tokens, &root));
}

test "parse_array: missing leading [ errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.R_SQUARE_BRACE};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_array(al, &tokens, &root));
}

test "parse_array: empty array []" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .R_SQUARE_BRACE };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array);
    try std.testing.expectEqual(@as(usize, 0), out.val.array.items.len);
    try std.testing.expectEqual(@as(usize, 0), out.tokens.len);
}

test "parse_array: single bool element [true]" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .TRUE, .R_SQUARE_BRACE };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array);
    try std.testing.expectEqual(@as(usize, 1), out.val.array.items.len);
}

test "parse_array: two elements [true,false]" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .TRUE, .COMMA, .FALSE, .R_SQUARE_BRACE };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array);
    try std.testing.expectEqual(@as(usize, 2), out.val.array.items.len);
}

test "parse_array: array of numbers [1,2,3]" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .NUMBER = "2" }, .COMMA,
        Tokens{ .NUMBER = "3" },
        .R_SQUARE_BRACE,
    };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array);
    try std.testing.expectEqual(@as(usize, 3), out.val.array.items.len);
}

test "parse_array: array of strings" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .STR = "a" }, .COMMA,
        Tokens{ .STR = "b" },
        .R_SQUARE_BRACE,
    };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array);
    try std.testing.expectEqual(@as(usize, 2), out.val.array.items.len);
}

test "parse_array: leading comma errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .COMMA, .TRUE, .R_SQUARE_BRACE };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_array(al, &tokens, &root));
}

test "parse_array: trailing comma errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .TRUE, .COMMA, .R_SQUARE_BRACE };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_array(al, &tokens, &root));
}

test "parse_array: missing closing bracket errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .TRUE };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_array(al, &tokens, &root));
}

test "parse_array: missing comma between elements errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .TRUE, .FALSE, .R_SQUARE_BRACE };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_array(al, &tokens, &root));
}

test "parse_array: nested arrays [[1],[2]]" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        .L_SQUARE_BRACE, Tokens{ .NUMBER = "1" }, .R_SQUARE_BRACE, .COMMA,
        .L_SQUARE_BRACE, Tokens{ .NUMBER = "2" }, .R_SQUARE_BRACE,
        .R_SQUARE_BRACE,
    };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array);
    try std.testing.expectEqual(@as(usize, 2), out.val.array.items.len);
}

test "parse_array: leftover tokens after ]" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .R_SQUARE_BRACE, .COMMA, .TRUE };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array);
    try std.testing.expectEqual(@as(usize, 2), out.tokens.len);
}

// ---------- parse_number ----------

test "parse_number: empty errors" {
    const tokens: []const Tokens = &.{};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_number(tokens));
}

test "parse_number: integer 0" {
    const tokens = [_]Tokens{ Tokens{ .NUMBER = "0" } };
    const out = try syntax_mod.parse_number(&tokens);
    try std.testing.expectEqual(std.meta.Tag(Value).integer, std.meta.activeTag(out.val));
    try std.testing.expectEqual(@as(i64, 0), out.val.integer);
}

test "parse_number: large integer" {
    const tokens = [_]Tokens{ Tokens{ .NUMBER = "9223372036854775807" } };
    const out = try syntax_mod.parse_number(&tokens);
    try std.testing.expectEqual(std.meta.Tag(Value).integer, std.meta.activeTag(out.val));
}

test "parse_number: float fraction" {
    const tokens = [_]Tokens{ Tokens{ .NUMBER = "0.5" } };
    const out = try syntax_mod.parse_number(&tokens);
    try std.testing.expectEqual(std.meta.Tag(Value).float, std.meta.activeTag(out.val));
}

test "parse_number: float exponent" {
    const tokens = [_]Tokens{ Tokens{ .NUMBER = "1e3" } };
    const out = try syntax_mod.parse_number(&tokens);
    try std.testing.expectEqual(std.meta.Tag(Value).float, std.meta.activeTag(out.val));
}

test "parse_number: leftover tokens preserved" {
    const tokens = [_]Tokens{ Tokens{ .NUMBER = "1" }, .COMMA, .TRUE };
    const out = try syntax_mod.parse_number(&tokens);
    try std.testing.expectEqual(@as(usize, 2), out.tokens.len);
}

// ---------- parse_object ----------

test "parse_object: empty token slice errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens: []const Tokens = &.{};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_object(al, tokens, &root));
}

test "parse_object: missing leading { errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{.R_CURLY_BRACE};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_object(al, &tokens, &root));
}

test "parse_object: empty object {}" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_CURLY_BRACE, .R_CURLY_BRACE };
    _ = try syntax_mod.parse_object(al, &tokens, &root);
}

test "parse_object: single key-value {\"a\":1}" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "1" },
        .R_CURLY_BRACE,
    };
    const out = try syntax_mod.parse_object(al, &tokens, &root);
    defer syntax_mod.deinit_value(al, out.val);
}

test "parse_object: multi key-value" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "b" }, .COLON, Tokens{ .NUMBER = "2" },
        .R_CURLY_BRACE,
    };
    const out = try syntax_mod.parse_object(al, &tokens, &root);
    defer syntax_mod.deinit_value(al, out.val);
}

test "parse_object: missing colon errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, Tokens{ .NUMBER = "1" },
        .R_CURLY_BRACE,
    };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_object(al, &tokens, &root));
}

test "parse_object: non-string key errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .NUMBER = "1" }, .COLON, Tokens{ .NUMBER = "2" },
        .R_CURLY_BRACE,
    };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_object(al, &tokens, &root));
}

test "parse_object: duplicate key errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "2" },
        .R_CURLY_BRACE,
    };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_object(al, &tokens, &root));
}

test "parse_object: missing closing brace errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "1" },
    };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_object(al, &tokens, &root));
}

test "parse_object: object with array value" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "k" }, .COLON,
        .L_SQUARE_BRACE, Tokens{ .NUMBER = "1" }, .COMMA, Tokens{ .NUMBER = "2" }, .R_SQUARE_BRACE,
        .R_CURLY_BRACE,
    };
    const out = try syntax_mod.parse_object(al, &tokens, &root);
    defer syntax_mod.deinit_value(al, out.val);
}

test "parse_object: nested object value" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "outer" }, .COLON,
        .L_CURLY_BRACE,
        Tokens{ .STR = "inner" }, .COLON, Tokens{ .NUMBER = "1" },
        .R_CURLY_BRACE,
        .R_CURLY_BRACE,
    };
    const out = try syntax_mod.parse_object(al, &tokens, &root);
    defer syntax_mod.deinit_value(al, out.val);
}

test "parse_object: STR after STR (missing colon and value) errors" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, Tokens{ .STR = "b" },
        .R_CURLY_BRACE,
    };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_object(al, &tokens, &root));
}

// ---------- check_for_key ----------

test "check_for_key: empty list returns false" {
    const al = std.testing.allocator;
    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(al);

    try std.testing.expectEqual(false, syntax_mod.check_for_key(keys, "x"));
}

test "check_for_key: present returns true" {
    const al = std.testing.allocator;
    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(al);

    const k = "hello";
    try keys.append(al, k);
    try std.testing.expectEqual(true, syntax_mod.check_for_key(keys, k));
}

test "check_for_key: absent returns false" {
    const al = std.testing.allocator;
    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(al);

    try keys.append(al, "abc");
    try std.testing.expectEqual(false, syntax_mod.check_for_key(keys, "xyz"));
}

// ---------- index_plain_objects ----------

test "index_plain_objects: empty keys is a no-op" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const plain = Object_plain{ .keys = .empty, .values = .empty };
    try syntax_mod.index_plain_object(al, &root, plain, 0);
    try std.testing.expectEqual(@as(u32, 0), root.indexes.count());
}

test "index_plain_objects: populates index map" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(al);
    try keys.append(al, "a");
    try keys.append(al, "b");

    const plain = Object_plain{ .keys = keys, .values = .empty };
    try syntax_mod.index_plain_object(al, &root, plain, 0);
    try std.testing.expect(root.indexes.count() >= 2);
}

// ---------- parse_syntax: full pipeline ----------

test "parse_syntax: empty input errors" {
    const al = std.testing.allocator;
    const tokens: []const Tokens = &.{};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_syntax(al, tokens));
}

test "parse_syntax: bare true" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{.TRUE};
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    try std.testing.expectEqual(std.meta.Tag(Value).boolean, std.meta.activeTag(root.value));
}

test "parse_syntax: bare null" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{.NULL};
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    try std.testing.expectEqual(std.meta.Tag(Value).null_obj, std.meta.activeTag(root.value));
}

test "parse_syntax: bare integer" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{ Tokens{ .NUMBER = "42" } };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    try std.testing.expectEqual(std.meta.Tag(Value).integer, std.meta.activeTag(root.value));
}

test "parse_syntax: empty object" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{ .L_CURLY_BRACE, .R_CURLY_BRACE };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
}

test "parse_syntax: empty array" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .R_SQUARE_BRACE };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value);
    try std.testing.expectEqual(std.meta.Tag(Value).array, std.meta.activeTag(root.value));
}

test "parse_syntax: simple object {\"a\":1}" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "1" },
        .R_CURLY_BRACE,
    };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value);
}

test "parse_syntax: trailing tokens error" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{ .TRUE, .FALSE };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_syntax(al, &tokens));
}

test "parse_syntax: object trailing tokens error" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE, .R_CURLY_BRACE,
        .COMMA,
    };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_syntax(al, &tokens));
}

test "parse_syntax: array of mixed values" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        .TRUE, .COMMA,
        Tokens{ .STR = "x" }, .COMMA,
        Tokens{ .NUMBER = "3" }, .COMMA,
        .NULL,
        .R_SQUARE_BRACE,
    };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value);
    try std.testing.expectEqual(std.meta.Tag(Value).array, std.meta.activeTag(root.value));
}

test "parse_syntax: deeply nested arrays" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE, .L_SQUARE_BRACE, .L_SQUARE_BRACE, .R_SQUARE_BRACE, .R_SQUARE_BRACE, .R_SQUARE_BRACE,
    };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value);
}

test "parse_syntax: object containing array containing object" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "k" }, .COLON,
        .L_SQUARE_BRACE,
        .L_CURLY_BRACE,
        Tokens{ .STR = "n" }, .COLON, Tokens{ .NUMBER = "1" },
        .R_CURLY_BRACE,
        .R_SQUARE_BRACE,
        .R_CURLY_BRACE,
    };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value);
}

test "parse_syntax: unmatched [ errors" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .TRUE };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_syntax(al, &tokens));
}

test "parse_syntax: unmatched { errors" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "1" },
    };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_syntax(al, &tokens));
}

test "parse_syntax: lone COMMA errors" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{.COMMA};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_syntax(al, &tokens));
}

test "parse_syntax: lone COLON errors" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{.COLON};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_syntax(al, &tokens));
}

test "parse_syntax: object with float value" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "pi" }, .COLON, Tokens{ .NUMBER = "3.14" },
        .R_CURLY_BRACE,
    };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value);
}

test "parse_syntax: array of strings" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .STR = "alpha" }, .COMMA,
        Tokens{ .STR = "beta" }, .COMMA,
        Tokens{ .STR = "gamma" },
        .R_SQUARE_BRACE,
    };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value);
}

test "parse_syntax: large object many keys" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "b" }, .COLON, Tokens{ .NUMBER = "2" }, .COMMA,
        Tokens{ .STR = "c" }, .COLON, Tokens{ .NUMBER = "3" }, .COMMA,
        Tokens{ .STR = "d" }, .COLON, Tokens{ .NUMBER = "4" }, .COMMA,
        Tokens{ .STR = "e" }, .COLON, Tokens{ .NUMBER = "5" },
        .R_CURLY_BRACE,
    };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value);
}

// ---------- unescape_string ----------

test "unescape_string: plain ascii" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "hello");
    defer al.free(out);
    try std.testing.expectEqualSlices(u8, "hello", out);
}

test "unescape_string: empty string" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "");
    defer al.free(out);
    try std.testing.expectEqual(@as(usize, 0), out.len);
}

test "unescape_string: newline escape" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "line\\nbreak");
    defer al.free(out);
    try std.testing.expectEqualSlices(u8, "line\nbreak", out);
}

test "unescape_string: tab and carriage return" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "a\\tb\\rc");
    defer al.free(out);
    try std.testing.expectEqualSlices(u8, "a\tb\rc", out);
}

test "unescape_string: escaped quote and backslash" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "a\\\"b\\\\c");
    defer al.free(out);
    try std.testing.expectEqualSlices(u8, "a\"b\\c", out);
}

test "unescape_string: \\u0041 decodes to A" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "\\u0041");
    defer al.free(out);
    try std.testing.expectEqualSlices(u8, "A", out);
}

test "unescape_string: surrogate pair decodes to emoji" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "\\uD83D\\uDE00");
    defer al.free(out);
    try std.testing.expectEqualSlices(u8, "\xF0\x9F\x98\x80", out);
}

test "unescape_string: \\u00A9 copyright sign UTF-8" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "\\u00A9");
    defer al.free(out);
    try std.testing.expectEqualSlices(u8, "\xC2\xA9", out);
}

test "unescape_string: raw UTF-8 multibyte passes through" {
    const al = std.testing.allocator;
    const out = try syntax_mod.unescape_string(al, "caf\xC3\xA9");
    defer al.free(out);
    try std.testing.expectEqualSlices(u8, "caf\xC3\xA9", out);
}

// ---------- complex parse_syntax scenarios ----------

test "parse_syntax: object with string value - content verified" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "key" }, .COLON, Tokens{ .STR = "val" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqualSlices(u8, "key", obj.keys.items[0]);
    try std.testing.expectEqualSlices(u8, "val", obj.values.items[0].string);
}

test "parse_syntax: object with escape in value string" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "msg" }, .COLON, Tokens{ .STR = "hello\\nworld" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    try std.testing.expectEqualSlices(u8, "hello\nworld", root.value.Object.plain.values.items[0].string);
}

test "parse_syntax: object with escape in key" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "hel\\nlo" }, .COLON, Tokens{ .NUMBER = "1" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    try std.testing.expectEqualSlices(u8, "hel\nlo", root.value.Object.plain.keys.items[0]);
}

test "parse_syntax: array of strings content verified" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .STR = "foo" }, .COMMA,
        Tokens{ .STR = "bar" },
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 2), arr.items.len);
    try std.testing.expectEqualSlices(u8, "foo", arr.items[0].string);
    try std.testing.expectEqualSlices(u8, "bar", arr.items[1].string);
}

test "parse_syntax: object all value types" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "s" }, .COLON, Tokens{ .STR = "hi" },        .COMMA,
        Tokens{ .STR = "n" }, .COLON, Tokens{ .NUMBER = "42" },     .COMMA,
        Tokens{ .STR = "f" }, .COLON, Tokens{ .NUMBER = "1.5" },    .COMMA,
        Tokens{ .STR = "b" }, .COLON, .TRUE,                        .COMMA,
        Tokens{ .STR = "z" }, .COLON, .NULL,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqual(@as(usize, 5), obj.keys.items.len);
    try std.testing.expectEqualSlices(u8, "hi", obj.values.items[0].string);
    try std.testing.expectEqual(@as(i64, 42), obj.values.items[1].integer);
    try std.testing.expectEqual(true, obj.values.items[3].boolean);
    try std.testing.expectEqual(std.meta.Tag(Value).null_obj, std.meta.activeTag(obj.values.items[4]));
}

test "parse_syntax: array of objects" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        .L_CURLY_BRACE, Tokens{ .STR = "x" }, .COLON, Tokens{ .NUMBER = "1" }, .R_CURLY_BRACE, .COMMA,
        .L_CURLY_BRACE, Tokens{ .STR = "x" }, .COLON, Tokens{ .NUMBER = "2" }, .R_CURLY_BRACE,
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 2), arr.items.len);
    try std.testing.expectEqual(std.meta.Tag(Value).Object, std.meta.activeTag(arr.items[0]));
    try std.testing.expectEqual(std.meta.Tag(Value).Object, std.meta.activeTag(arr.items[1]));
}

test "parse_syntax: object keys all present and correct" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "first" },  .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "second" }, .COLON, Tokens{ .NUMBER = "2" }, .COMMA,
        Tokens{ .STR = "third" },  .COLON, Tokens{ .NUMBER = "3" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqual(@as(usize, 3), obj.keys.items.len);
    try std.testing.expectEqualSlices(u8, "first",  obj.keys.items[0]);
    try std.testing.expectEqualSlices(u8, "second", obj.keys.items[1]);
    try std.testing.expectEqualSlices(u8, "third",  obj.keys.items[2]);
    try std.testing.expectEqual(@as(i64, 1), obj.values.items[0].integer);
    try std.testing.expectEqual(@as(i64, 2), obj.values.items[1].integer);
    try std.testing.expectEqual(@as(i64, 3), obj.values.items[2].integer);
}

test "parse_syntax: nested object content verified" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "outer" }, .COLON,
        .L_CURLY_BRACE,
        Tokens{ .STR = "inner" }, .COLON, Tokens{ .STR = "value" },
        .R_CURLY_BRACE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const inner = root.value.Object.plain.values.items[0].Object.plain;
    try std.testing.expectEqualSlices(u8, "inner", inner.keys.items[0]);
    try std.testing.expectEqualSlices(u8, "value", inner.values.items[0].string);
}

test "parse_syntax: object with array value content verified" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "nums" }, .COLON,
        .L_SQUARE_BRACE, Tokens{ .NUMBER = "10" }, .COMMA, Tokens{ .NUMBER = "20" }, .R_SQUARE_BRACE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.Object.plain.values.items[0].array;
    try std.testing.expectEqual(@as(usize, 2), arr.items.len);
    try std.testing.expectEqual(@as(i64, 10), arr.items[0].integer);
    try std.testing.expectEqual(@as(i64, 20), arr.items[1].integer);
}

test "parse_syntax: array of mixed scalars content verified" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .NUMBER = "1" }, .COMMA,
        .TRUE,                   .COMMA,
        .NULL,                   .COMMA,
        Tokens{ .STR = "end" },
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 4), arr.items.len);
    try std.testing.expectEqual(@as(i64, 1), arr.items[0].integer);
    try std.testing.expectEqual(true, arr.items[1].boolean);
    try std.testing.expectEqual(std.meta.Tag(Value).null_obj, std.meta.activeTag(arr.items[2]));
    try std.testing.expectEqualSlices(u8, "end", arr.items[3].string);
}

test "parse_syntax: string with unicode escape content verified" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .STR = "\\u0041\\u0042\\u0043" },
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    try std.testing.expectEqualSlices(u8, "ABC", root.value.array.items[0].string);
}

// ---------- indexing logic ----------
// Objects switch from Object_plain to Object_indexed when the sum of key string
// lengths in parse_plain reaches 512.  The trigger structure is:
//   { <long_key>: v1, ... }
// After the first key-value-comma pair, the loop re-checks `total < 512`.
// If already >= 512 it exits and calls parse_indexed for remaining pairs.

const long_key = "a" ** 512;

test "indexed: basic values are correct" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "b" },      .COLON, Tokens{ .NUMBER = "2" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);

    try std.testing.expectEqual(std.meta.Tag(Object).indexed, std.meta.activeTag(root.value.Object));
    const obj = root.value.Object.indexed;
    try std.testing.expectEqual(@as(usize, 2), obj.values.items.len);
    try std.testing.expectEqual(@as(i64, 1), obj.values.items[0].integer);
    try std.testing.expectEqual(@as(i64, 2), obj.values.items[1].integer);
}

test "indexed: map lookup by key returns correct position" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "10" }, .COMMA,
        Tokens{ .STR = "x" },      .COLON, Tokens{ .NUMBER = "20" }, .COMMA,
        Tokens{ .STR = "y" },      .COLON, Tokens{ .NUMBER = "30" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);

    const id = root.value.Object.indexed.ident_postfix;
    const idx_long = root.indexes.get(.{ .key = long_key, .obj_id = id });
    const idx_x    = root.indexes.get(.{ .key = "x",        .obj_id = id });
    const idx_y    = root.indexes.get(.{ .key = "y",        .obj_id = id });

    try std.testing.expect(idx_long != null);
    try std.testing.expect(idx_x    != null);
    try std.testing.expect(idx_y    != null);
    try std.testing.expectEqual(@as(u64, 0), idx_long.?);
    try std.testing.expectEqual(@as(u64, 1), idx_x.?);
    try std.testing.expectEqual(@as(u64, 2), idx_y.?);
}

test "indexed: duplicate key in plain section errors (no leak)" {
    // duplicate detected inside parse_plain before indexing
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "k" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "k" }, .COLON, Tokens{ .NUMBER = "2" },
        .R_CURLY_BRACE,
    };
    try std.testing.expectError(
        error.incorrect_value_token,
        syntax_mod.parse_syntax(al, &tokens),
    );
}

test "indexed: duplicate key in indexed section errors (no leak)" {
    // first key triggers plain->indexed handoff; duplicate in indexed section
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "dup" },    .COLON, Tokens{ .NUMBER = "2" }, .COMMA,
        Tokens{ .STR = "dup" },    .COLON, Tokens{ .NUMBER = "3" },
        .R_CURLY_BRACE,
    };
    try std.testing.expectError(
        error.incorrect_value_token,
        syntax_mod.parse_syntax(al, &tokens),
    );
}

test "indexed: missing closing brace errors (no leak)" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "b" },      .COLON, Tokens{ .NUMBER = "2" },
        // missing R_CURLY_BRACE
    };
    try std.testing.expectError(
        error.incorrect_value_token,
        syntax_mod.parse_syntax(al, &tokens),
    );
}

test "indexed: trailing comma errors (no leak)" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "b" },      .COLON, Tokens{ .NUMBER = "2" }, .COMMA,
        .R_CURLY_BRACE,
    };
    try std.testing.expectError(
        error.incorrect_value_token,
        syntax_mod.parse_syntax(al, &tokens),
    );
}

test "indexed: two separate indexed objects in array have different IDs" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        // first object
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "k" },      .COLON, Tokens{ .NUMBER = "2" },
        .R_CURLY_BRACE, .COMMA,
        // second object — same key names, different object
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "3" }, .COMMA,
        Tokens{ .STR = "k" },      .COLON, Tokens{ .NUMBER = "4" },
        .R_CURLY_BRACE,
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);

    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 2), arr.items.len);

    const id0 = arr.items[0].Object.indexed.ident_postfix;
    const id1 = arr.items[1].Object.indexed.ident_postfix;
    try std.testing.expect(id0 != id1);

    // same key name maps to different positions under different IDs
    const p0 = root.indexes.get(.{ .key = "k", .obj_id = id0 });
    const p1 = root.indexes.get(.{ .key = "k", .obj_id = id1 });
    try std.testing.expect(p0 != null);
    try std.testing.expect(p1 != null);
    try std.testing.expectEqual(@as(u64, 1), p0.?);
    try std.testing.expectEqual(@as(u64, 1), p1.?);
}

test "indexed: nested indexed inside plain outer" {
    // outer is plain (short keys), inner is indexed (long key)
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "outer" }, .COLON,
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "7" }, .COMMA,
        Tokens{ .STR = "n" },      .COLON, Tokens{ .NUMBER = "8" },
        .R_CURLY_BRACE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);

    const outer = root.value.Object.plain;
    try std.testing.expectEqual(@as(usize, 1), outer.keys.items.len);
    const inner = outer.values.items[0].Object.indexed;
    try std.testing.expectEqual(@as(i64, 7), inner.values.items[0].integer);
    try std.testing.expectEqual(@as(i64, 8), inner.values.items[1].integer);
}

test "indexed: string values in indexed object" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .STR = "hello" }, .COMMA,
        Tokens{ .STR = "b" },      .COLON, Tokens{ .STR = "world" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);

    const obj = root.value.Object.indexed;
    try std.testing.expectEqualSlices(u8, "hello", obj.values.items[0].string);
    try std.testing.expectEqualSlices(u8, "world", obj.values.items[1].string);
}

test "indexed: many keys in indexed section" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON, Tokens{ .NUMBER = "0" }, .COMMA,
        Tokens{ .STR = "k1" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .STR = "k2" }, .COLON, Tokens{ .NUMBER = "2" }, .COMMA,
        Tokens{ .STR = "k3" }, .COLON, Tokens{ .NUMBER = "3" }, .COMMA,
        Tokens{ .STR = "k4" }, .COLON, Tokens{ .NUMBER = "4" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);

    const obj = root.value.Object.indexed;
    try std.testing.expectEqual(@as(usize, 5), obj.values.items.len);

    const id = obj.ident_postfix;
    try std.testing.expectEqual(@as(u64, 0), root.indexes.get(.{ .key = long_key, .obj_id = id }).?);
    try std.testing.expectEqual(@as(u64, 3), root.indexes.get(.{ .key = "k3",      .obj_id = id }).?);
    try std.testing.expectEqual(@as(u64, 4), root.indexes.get(.{ .key = "k4",      .obj_id = id }).?);
}

// ---------- complex / random tests ----------

test "complex: flat object with all scalar types" {
    // { "i": -99, "f": 1.5e2, "s": "hi", "b": false, "n": null, "t": true }
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "i" }, .COLON, Tokens{ .NUMBER = "-99" },  .COMMA,
        Tokens{ .STR = "f" }, .COLON, Tokens{ .NUMBER = "1.5e2" }, .COMMA,
        Tokens{ .STR = "s" }, .COLON, Tokens{ .STR = "hi" },       .COMMA,
        Tokens{ .STR = "b" }, .COLON, .FALSE,                       .COMMA,
        Tokens{ .STR = "n" }, .COLON, .NULL,                        .COMMA,
        Tokens{ .STR = "t" }, .COLON, .TRUE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqual(@as(usize, 6), obj.values.items.len);
    try std.testing.expectEqual(@as(i64, -99),  obj.values.items[0].integer);
    try std.testing.expectEqual(std.meta.Tag(Value).float, std.meta.activeTag(obj.values.items[1]));
    try std.testing.expectEqualSlices(u8, "hi", obj.values.items[2].string);
    try std.testing.expectEqual(false,           obj.values.items[3].boolean);
    try std.testing.expectEqual(std.meta.Tag(Value).null_obj, std.meta.activeTag(obj.values.items[4]));
    try std.testing.expectEqual(true,            obj.values.items[5].boolean);
}

test "complex: array of mixed scalars, 10 elements" {
    // [0, 1, 2, 3, 4, 5, true, false, null, "end"]
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .NUMBER = "0" }, .COMMA,
        Tokens{ .NUMBER = "1" }, .COMMA,
        Tokens{ .NUMBER = "2" }, .COMMA,
        Tokens{ .NUMBER = "3" }, .COMMA,
        Tokens{ .NUMBER = "4" }, .COMMA,
        Tokens{ .NUMBER = "5" }, .COMMA,
        .TRUE,                   .COMMA,
        .FALSE,                  .COMMA,
        .NULL,                   .COMMA,
        Tokens{ .STR = "end" },
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 10), arr.items.len);
    try std.testing.expectEqual(@as(i64, 0), arr.items[0].integer);
    try std.testing.expectEqual(@as(i64, 5), arr.items[5].integer);
    try std.testing.expectEqual(true,  arr.items[6].boolean);
    try std.testing.expectEqual(false, arr.items[7].boolean);
    try std.testing.expectEqual(std.meta.Tag(Value).null_obj, std.meta.activeTag(arr.items[8]));
    try std.testing.expectEqualSlices(u8, "end", arr.items[9].string);
}

test "complex: object whose values are all arrays" {
    // { "a": [1,2], "b": [3,4], "c": [5,6] }
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON,
            .L_SQUARE_BRACE, Tokens{ .NUMBER = "1" }, .COMMA, Tokens{ .NUMBER = "2" }, .R_SQUARE_BRACE,
        .COMMA,
        Tokens{ .STR = "b" }, .COLON,
            .L_SQUARE_BRACE, Tokens{ .NUMBER = "3" }, .COMMA, Tokens{ .NUMBER = "4" }, .R_SQUARE_BRACE,
        .COMMA,
        Tokens{ .STR = "c" }, .COLON,
            .L_SQUARE_BRACE, Tokens{ .NUMBER = "5" }, .COMMA, Tokens{ .NUMBER = "6" }, .R_SQUARE_BRACE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqual(@as(usize, 3), obj.keys.items.len);
    try std.testing.expectEqual(@as(i64, 1), obj.values.items[0].array.items[0].integer);
    try std.testing.expectEqual(@as(i64, 4), obj.values.items[1].array.items[1].integer);
    try std.testing.expectEqual(@as(i64, 6), obj.values.items[2].array.items[1].integer);
}

test "complex: array of objects, each with two fields" {
    // [{"x":1,"y":2}, {"x":3,"y":4}, {"x":5,"y":6}]
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        .L_CURLY_BRACE, Tokens{ .STR = "x" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA, Tokens{ .STR = "y" }, .COLON, Tokens{ .NUMBER = "2" }, .R_CURLY_BRACE, .COMMA,
        .L_CURLY_BRACE, Tokens{ .STR = "x" }, .COLON, Tokens{ .NUMBER = "3" }, .COMMA, Tokens{ .STR = "y" }, .COLON, Tokens{ .NUMBER = "4" }, .R_CURLY_BRACE, .COMMA,
        .L_CURLY_BRACE, Tokens{ .STR = "x" }, .COLON, Tokens{ .NUMBER = "5" }, .COMMA, Tokens{ .STR = "y" }, .COLON, Tokens{ .NUMBER = "6" }, .R_CURLY_BRACE,
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 3), arr.items.len);
    try std.testing.expectEqual(@as(i64, 1), arr.items[0].Object.plain.values.items[0].integer);
    try std.testing.expectEqual(@as(i64, 4), arr.items[1].Object.plain.values.items[1].integer);
    try std.testing.expectEqual(@as(i64, 5), arr.items[2].Object.plain.values.items[0].integer);
}

test "complex: 4-level deep nesting" {
    // {"a":{"b":{"c":{"d":42}}}}
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE, Tokens{ .STR = "a" }, .COLON,
          .L_CURLY_BRACE, Tokens{ .STR = "b" }, .COLON,
            .L_CURLY_BRACE, Tokens{ .STR = "c" }, .COLON,
              .L_CURLY_BRACE, Tokens{ .STR = "d" }, .COLON, Tokens{ .NUMBER = "42" },
              .R_CURLY_BRACE,
            .R_CURLY_BRACE,
          .R_CURLY_BRACE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const d = root.value.Object.plain
        .values.items[0].Object.plain
        .values.items[0].Object.plain
        .values.items[0].Object.plain
        .values.items[0].integer;
    try std.testing.expectEqual(@as(i64, 42), d);
}

test "complex: object value is array of objects" {
    // {"items":[{"v":1},{"v":2},{"v":3}]}
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "items" }, .COLON,
        .L_SQUARE_BRACE,
          .L_CURLY_BRACE, Tokens{ .STR = "v" }, .COLON, Tokens{ .NUMBER = "1" }, .R_CURLY_BRACE, .COMMA,
          .L_CURLY_BRACE, Tokens{ .STR = "v" }, .COLON, Tokens{ .NUMBER = "2" }, .R_CURLY_BRACE, .COMMA,
          .L_CURLY_BRACE, Tokens{ .STR = "v" }, .COLON, Tokens{ .NUMBER = "3" }, .R_CURLY_BRACE,
        .R_SQUARE_BRACE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const items = root.value.Object.plain.values.items[0].array;
    try std.testing.expectEqual(@as(usize, 3), items.items.len);
    try std.testing.expectEqual(@as(i64, 1), items.items[0].Object.plain.values.items[0].integer);
    try std.testing.expectEqual(@as(i64, 2), items.items[1].Object.plain.values.items[0].integer);
    try std.testing.expectEqual(@as(i64, 3), items.items[2].Object.plain.values.items[0].integer);
}

test "complex: sibling arrays of different types" {
    // {"ints":[1,2,3],"strs":["a","b"],"bools":[true,false,true]}
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "ints" }, .COLON,
        .L_SQUARE_BRACE, Tokens{ .NUMBER = "1" }, .COMMA, Tokens{ .NUMBER = "2" }, .COMMA, Tokens{ .NUMBER = "3" }, .R_SQUARE_BRACE, .COMMA,
        Tokens{ .STR = "strs" }, .COLON,
        .L_SQUARE_BRACE, Tokens{ .STR = "a" }, .COMMA, Tokens{ .STR = "b" }, .R_SQUARE_BRACE, .COMMA,
        Tokens{ .STR = "bools" }, .COLON,
        .L_SQUARE_BRACE, .TRUE, .COMMA, .FALSE, .COMMA, .TRUE, .R_SQUARE_BRACE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqual(@as(usize, 3), obj.keys.items.len);
    try std.testing.expectEqual(@as(i64, 3),   obj.values.items[0].array.items[2].integer);
    try std.testing.expectEqual(@as(usize, 2), obj.values.items[1].array.items.len);
    try std.testing.expectEqual(true,           obj.values.items[2].array.items[0].boolean);
    try std.testing.expectEqual(false,          obj.values.items[2].array.items[1].boolean);
}

test "complex: empty arrays and objects as values" {
    // {"e_obj":{},"e_arr":[],"val":1}
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "e_obj" }, .COLON, .L_CURLY_BRACE,  .R_CURLY_BRACE,  .COMMA,
        Tokens{ .STR = "e_arr" }, .COLON, .L_SQUARE_BRACE, .R_SQUARE_BRACE, .COMMA,
        Tokens{ .STR = "val" },   .COLON, Tokens{ .NUMBER = "1" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqual(std.meta.Tag(Object).plain, std.meta.activeTag(obj.values.items[0].Object));
    try std.testing.expectEqual(std.meta.Tag(Value).array,  std.meta.activeTag(obj.values.items[1]));
    try std.testing.expectEqual(@as(usize, 0), obj.values.items[1].array.items.len);
    try std.testing.expectEqual(@as(i64, 1), obj.values.items[2].integer);
}

test "complex: array containing empty array and empty object" {
    // [[],[],{}]
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        .L_SQUARE_BRACE, .R_SQUARE_BRACE, .COMMA,
        .L_SQUARE_BRACE, .R_SQUARE_BRACE, .COMMA,
        .L_CURLY_BRACE,  .R_CURLY_BRACE,
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 3), arr.items.len);
    try std.testing.expectEqual(std.meta.Tag(Value).array,  std.meta.activeTag(arr.items[0]));
    try std.testing.expectEqual(std.meta.Tag(Value).array,  std.meta.activeTag(arr.items[1]));
    try std.testing.expectEqual(std.meta.Tag(Value).Object, std.meta.activeTag(arr.items[2]));
}

test "complex: negative and fractional numbers" {
    // [-1, -0.5, 1e-3, -1e10]
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .NUMBER = "-1" },    .COMMA,
        Tokens{ .NUMBER = "-0.5" },  .COMMA,
        Tokens{ .NUMBER = "1e-3" },  .COMMA,
        Tokens{ .NUMBER = "-1e10" },
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 4), arr.items.len);
    try std.testing.expectEqual(@as(i64, -1), arr.items[0].integer);
    try std.testing.expectEqual(std.meta.Tag(Value).float, std.meta.activeTag(arr.items[1]));
    try std.testing.expectEqual(std.meta.Tag(Value).float, std.meta.activeTag(arr.items[2]));
    try std.testing.expectEqual(std.meta.Tag(Value).float, std.meta.activeTag(arr.items[3]));
}

test "complex: object with escaped keys and string values" {
    // {"he\\nllo": "wo\\trld", "q\\"ote": "back\\\\slash"}
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "he\\nllo" },    .COLON, Tokens{ .STR = "wo\\trld" },      .COMMA,
        Tokens{ .STR = "back\\\\key" }, .COLON, Tokens{ .STR = "back\\\\val" },
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqualSlices(u8, "he\nllo",    obj.keys.items[0]);
    try std.testing.expectEqualSlices(u8, "wo\trld",    obj.values.items[0].string);
    try std.testing.expectEqualSlices(u8, "back\\key",  obj.keys.items[1]);
    try std.testing.expectEqualSlices(u8, "back\\val",  obj.values.items[1].string);
}

test "complex: deeply nested arrays" {
    // [[[[[42]]]]]
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE, .L_SQUARE_BRACE, .L_SQUARE_BRACE, .L_SQUARE_BRACE, .L_SQUARE_BRACE,
        Tokens{ .NUMBER = "42" },
        .R_SQUARE_BRACE, .R_SQUARE_BRACE, .R_SQUARE_BRACE, .R_SQUARE_BRACE, .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const v = root.value
        .array.items[0]
        .array.items[0]
        .array.items[0]
        .array.items[0]
        .array.items[0]
        .integer;
    try std.testing.expectEqual(@as(i64, 42), v);
}

test "complex: record-like object with nested address" {
    // {"name":"Alice","age":30,"active":true,"score":9.5,"address":{"city":"NY","zip":"10001"}}
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "name" },   .COLON, Tokens{ .STR = "Alice" },   .COMMA,
        Tokens{ .STR = "age" },    .COLON, Tokens{ .NUMBER = "30" },   .COMMA,
        Tokens{ .STR = "active" }, .COLON, .TRUE,                       .COMMA,
        Tokens{ .STR = "score" },  .COLON, Tokens{ .NUMBER = "9.5" },  .COMMA,
        Tokens{ .STR = "address" }, .COLON,
        .L_CURLY_BRACE,
            Tokens{ .STR = "city" }, .COLON, Tokens{ .STR = "NY" },      .COMMA,
            Tokens{ .STR = "zip" },  .COLON, Tokens{ .STR = "10001" },
        .R_CURLY_BRACE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.plain;
    try std.testing.expectEqualSlices(u8, "Alice", obj.values.items[0].string);
    try std.testing.expectEqual(@as(i64, 30),      obj.values.items[1].integer);
    try std.testing.expectEqual(true,               obj.values.items[2].boolean);
    const addr = obj.values.items[4].Object.plain;
    try std.testing.expectEqualSlices(u8, "NY",    addr.values.items[0].string);
    try std.testing.expectEqualSlices(u8, "10001", addr.values.items[1].string);
}

test "complex: list of records with nulls" {
    // [{"id":1,"val":"a"},{"id":2,"val":null},{"id":3,"val":"c"}]
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        .L_CURLY_BRACE, Tokens{ .STR = "id" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA, Tokens{ .STR = "val" }, .COLON, Tokens{ .STR = "a" },  .R_CURLY_BRACE, .COMMA,
        .L_CURLY_BRACE, Tokens{ .STR = "id" }, .COLON, Tokens{ .NUMBER = "2" }, .COMMA, Tokens{ .STR = "val" }, .COLON, .NULL,                   .R_CURLY_BRACE, .COMMA,
        .L_CURLY_BRACE, Tokens{ .STR = "id" }, .COLON, Tokens{ .NUMBER = "3" }, .COMMA, Tokens{ .STR = "val" }, .COLON, Tokens{ .STR = "c" },  .R_CURLY_BRACE,
        .R_SQUARE_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const arr = root.value.array;
    try std.testing.expectEqual(@as(usize, 3), arr.items.len);
    try std.testing.expectEqualSlices(u8, "a", arr.items[0].Object.plain.values.items[1].string);
    try std.testing.expectEqual(std.meta.Tag(Value).null_obj, std.meta.activeTag(arr.items[1].Object.plain.values.items[1]));
    try std.testing.expectEqual(@as(i64, 3), arr.items[2].Object.plain.values.items[0].integer);
}

test "complex: indexed object with array values" {
    // { <long_key>: [1,2,3], "b": [4,5], "c": true }
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON,
            .L_SQUARE_BRACE, Tokens{ .NUMBER = "1" }, .COMMA, Tokens{ .NUMBER = "2" }, .COMMA, Tokens{ .NUMBER = "3" }, .R_SQUARE_BRACE,
        .COMMA,
        Tokens{ .STR = "b" }, .COLON,
            .L_SQUARE_BRACE, Tokens{ .NUMBER = "4" }, .COMMA, Tokens{ .NUMBER = "5" }, .R_SQUARE_BRACE,
        .COMMA,
        Tokens{ .STR = "c" }, .COLON, .TRUE,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.indexed;
    try std.testing.expectEqual(@as(usize, 3), obj.values.items.len);
    try std.testing.expectEqual(@as(i64, 3),   obj.values.items[0].array.items[2].integer);
    try std.testing.expectEqual(@as(i64, 4),   obj.values.items[1].array.items[0].integer);
    try std.testing.expectEqual(true,           obj.values.items[2].boolean);
}

test "complex: indexed object with nested plain object value" {
    // { <long_key>: {"x":1,"y":2}, "meta": null }
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = long_key }, .COLON,
            .L_CURLY_BRACE, Tokens{ .STR = "x" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA, Tokens{ .STR = "y" }, .COLON, Tokens{ .NUMBER = "2" }, .R_CURLY_BRACE,
        .COMMA,
        Tokens{ .STR = "meta" }, .COLON, .NULL,
        .R_CURLY_BRACE,
    };
    const root = try syntax_mod.parse_syntax(al, &tokens);
    defer syntax_mod.deinit_json(al, root);
    const obj = root.value.Object.indexed;
    const inner = obj.values.items[0].Object.plain;
    try std.testing.expectEqual(@as(i64, 1), inner.values.items[0].integer);
    try std.testing.expectEqual(@as(i64, 2), inner.values.items[1].integer);
    try std.testing.expectEqual(std.meta.Tag(Value).null_obj, std.meta.activeTag(obj.values.items[1]));
}

test "complex: error mid-array after strings allocated (no leak)" {
    // ["ok", "fine", <missing closing bracket>
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE,
        Tokens{ .STR = "ok" }, .COMMA, Tokens{ .STR = "fine" },
    };
    try std.testing.expectError(
        error.incorrect_value_token,
        syntax_mod.parse_syntax(al, &tokens),
    );
}

test "complex: error mid-object after string values allocated (no leak)" {
    // {"a":"hello","b":"world"  <- missing closing brace
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "a" }, .COLON, Tokens{ .STR = "hello" }, .COMMA,
        Tokens{ .STR = "b" }, .COLON, Tokens{ .STR = "world" },
    };
    try std.testing.expectError(
        error.incorrect_value_token,
        syntax_mod.parse_syntax(al, &tokens),
    );
}

test "complex: error inside nested object (no leak)" {
    // {"outer":{"a":1,"b":  <- value missing
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "outer" }, .COLON,
        .L_CURLY_BRACE,
            Tokens{ .STR = "a" }, .COLON, Tokens{ .NUMBER = "1" }, .COMMA,
            Tokens{ .STR = "b" }, .COLON,   // no value
        .R_CURLY_BRACE,
        .R_CURLY_BRACE,
    };
    try std.testing.expectError(
        error.incorrect_value_token,
        syntax_mod.parse_syntax(al, &tokens),
    );
}

test "complex: error inside nested array (no leak)" {
    // {"k":[[1,2,   <- unterminated inner array
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_CURLY_BRACE,
        Tokens{ .STR = "k" }, .COLON,
        .L_SQUARE_BRACE,
            .L_SQUARE_BRACE, Tokens{ .NUMBER = "1" }, .COMMA, Tokens{ .NUMBER = "2" }, .COMMA,
        // missing R_SQUARE_BRACE and outer close
    };
    try std.testing.expectError(
        error.incorrect_value_token,
        syntax_mod.parse_syntax(al, &tokens),
    );
}
