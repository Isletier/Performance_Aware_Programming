const std = @import("std");
const tokenize_mod = @import("tokenize.zig");
const syntax_mod = @import("syntax.zig");

pub const Tokens = tokenize_mod.Tokens;
pub const Errors = tokenize_mod.Errors;
pub const tokenize_literal = tokenize_mod.tokenize_literal;
pub const tokenize_string = tokenize_mod.tokenize_string;
pub const tokenize_number = tokenize_mod.tokenize_number;
pub const validate_number = tokenize_mod.validate_number;
pub const validate_fraction = tokenize_mod.validate_fraction;
pub const validate_exponent = tokenize_mod.validate_exponent;
pub const tokenize = tokenize_mod.tokenize;
pub const deinit_tokenize = tokenize_mod.deinit_tokenize;

pub fn parse(src: []const u8) !void {
    _ = src;
    return;
}

test {
    _ = @import("tokenize_test.zig");
    _ = @import("syntax_test.zig");
}
