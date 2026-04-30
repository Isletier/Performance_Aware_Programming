const std = @import("std");
const syntax_mod = @import("syntax.zig");
const tokenize_mod = @import("tokenize.zig");

const Tokens = tokenize_mod.Tokens;
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
    defer syntax_mod.deinit_array(al, out.val.array, true);
    try std.testing.expectEqual(@as(usize, 0), out.val.array.items.len);
    try std.testing.expectEqual(@as(usize, 0), out.tokens.len);
}

test "parse_array: single bool element [true]" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .TRUE, .R_SQUARE_BRACE };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array, true);
    try std.testing.expectEqual(@as(usize, 1), out.val.array.items.len);
}

test "parse_array: two elements [true,false]" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .TRUE, .COMMA, .FALSE, .R_SQUARE_BRACE };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array, true);
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
    defer syntax_mod.deinit_array(al, out.val.array, true);
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
    defer syntax_mod.deinit_array(al, out.val.array, true);
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
    defer syntax_mod.deinit_array(al, out.val.array, true);
    try std.testing.expectEqual(@as(usize, 2), out.val.array.items.len);
}

test "parse_array: leftover tokens after ]" {
    const al = std.testing.allocator;
    var root = make_root(al);
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .R_SQUARE_BRACE, .COMMA, .TRUE };
    const out = try syntax_mod.parse_array(al, &tokens, &root);
    defer syntax_mod.deinit_array(al, out.val.array, true);
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
    defer syntax_mod.deinit_value(al, out.val, true);
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
    defer syntax_mod.deinit_value(al, out.val, true);
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
    defer syntax_mod.deinit_value(al, out.val, true);
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
    defer syntax_mod.deinit_value(al, out.val, true);
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
    try syntax_mod.index_plain_object(&root, plain);
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
    try syntax_mod.index_plain_object(&root, plain);
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
    defer syntax_mod.deinit_value(al, root.value, true);
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
    defer syntax_mod.deinit_value(al, root.value, true);
    try std.testing.expectEqual(std.meta.Tag(Value).array, std.meta.activeTag(root.value));
}

test "parse_syntax: deeply nested arrays" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{
        .L_SQUARE_BRACE, .L_SQUARE_BRACE, .L_SQUARE_BRACE, .R_SQUARE_BRACE, .R_SQUARE_BRACE, .R_SQUARE_BRACE,
    };
    var root = try syntax_mod.parse_syntax(al, &tokens);
    defer root.indexes.deinit();
    defer syntax_mod.deinit_value(al, root.value, true);
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
    defer syntax_mod.deinit_value(al, root.value, true);
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
    defer syntax_mod.deinit_value(al, root.value, true);
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
    defer syntax_mod.deinit_value(al, root.value, true);
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
    defer syntax_mod.deinit_value(al, root.value, true);
}
