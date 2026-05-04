const std   = @import("std");
const Io    = std.Io;
const json  = @import("json");
const haver = @import("haverstine_ref").haverstine_ref;

fn to_f64(v: json.Value) f64 {
    return switch (v) {
        .float   => |f| f,
        .integer => |i| @floatFromInt(i),
        else     => unreachable,
    };
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const al = arena.allocator();

    var read_buf: [65536]u8 = undefined;
    var stdin_reader = Io.File.stdin().reader(init.io, &read_buf);
    const src = try stdin_reader.interface.allocRemaining(al, .unlimited);

    var root = try json.parse(al, src);

    const pairs = (try root.value.Object.get("pairs")).array;

    var sum: f64 = 0;
    const coef = 1.0 / @as(f64, @floatFromInt(pairs.items.len));

    for (pairs.items) |item| {
        var pair = item.Object;
        sum += coef * haver(
            (try pair.get("x1")).float,
            (try pair.get("y1")).float,
            (try pair.get("x2")).float,
            (try pair.get("y2")).float,
            6372.8,
        );
    }

    std.debug.print("Haverstine sum: {d}\n", .{sum});
}
