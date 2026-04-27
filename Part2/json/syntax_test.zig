const std = @import("std");
const syntax_mod = @import("syntax.zig");
const tokenize_mod = @import("tokenize.zig");

const Tokens = tokenize_mod.Tokens;
const RootObj = syntax_mod.RootObj;

fn empty_root() RootObj {
    return RootObj{
        .prefix_count = 0,
        .indexes = std.AutoHashMap([]const u8, syntax_mod.Value).init(std.testing.allocator),
        .value = .null_obj,
    };
}

test "parse_array: empty token slice returns error" {
    const al = std.testing.allocator;
    var root = empty_root();
    defer root.indexes.deinit();

    const tokens: []const Tokens = &.{};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_array(al, tokens, &root));
}

test "parse_array: missing leading [ returns error" {
    const al = std.testing.allocator;
    var root = empty_root();
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .R_SQUARE_BRACE };
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_array(al, &tokens, &root));
}

test "parse_array: empty array []" {
    const al = std.testing.allocator;
    var root = empty_root();
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ .L_SQUARE_BRACE, .R_SQUARE_BRACE };
    _ = try syntax_mod.parse_array(al, &tokens, &root);
}

test "parse_value: empty token slice returns error" {
    const al = std.testing.allocator;
    var root = empty_root();
    defer root.indexes.deinit();

    const tokens: []const Tokens = &.{};
    try std.testing.expectError(error.incorrect_value_token, syntax_mod.parse_value(al, tokens, &root));
}

test "parse_value: string token" {
    const al = std.testing.allocator;
    var root = empty_root();
    defer root.indexes.deinit();

    const tokens = [_]Tokens{ Tokens{ .STR = "hello" } };
    _ = try syntax_mod.parse_value(al, &tokens, &root);
}

test "parse_syntax: empty object {}" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{ .L_CURLY_BRACE, .R_CURLY_BRACE };
    _ = try syntax_mod.parse_syntax(al, &tokens);
}

test "parse_syntax: missing closing brace" {
    const al = std.testing.allocator;
    const tokens = [_]Tokens{ .L_CURLY_BRACE, .COMMA };
    try std.testing.expectError(error.object_closing_brace, syntax_mod.parse_syntax(al, &tokens));
}
