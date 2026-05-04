const std = @import("std");
const Io = std.Io;
const print = std.debug.print;

const haverstine = @import("haverstine_ref").haverstine_ref;

pub fn print_help_message() void {
    print("Usage: haverstine_gen [cluster/universal] [seed] [count]\n", .{});
}

const gen_type = enum {
    cluster,
    universal
};

const CLUSTER_NUM_CAP = 8;
const CLUSTER_RANGE_CAP = 180.0;

pub fn main(init: std.process.Init) !void {
    var it = init.minimal.args.iterate();
    _ = it.next();

    var str = it.next() orelse {
        print_help_message();
        return;
    };

    const g_type: gen_type = if (std.mem.eql(u8, str, "cluster"))
        gen_type.cluster
    else if (std.mem.eql(u8, str, "universal"))
        gen_type.universal
    else {
        print_help_message();
        return;
    };

    str = it.next() orelse {
        print_help_message();
        return;
    };
    const seed = std.fmt.parseInt(u64, str, 10) catch {
        print_help_message();
        return;
    };

    str = it.next() orelse {
        print_help_message();
        return;
    };

    const count = std.fmt.parseInt(u64, str, 10) catch {
        print_help_message();
        return;
    };

    try gen(init.io, g_type, seed, count);
}

pub fn rand_with_pin(rand: std.Random, comptime T: type, range: T, pin_point: T) T {
    const value = rand.float(T) * range;

    return @mod(value, range) + pin_point - range / 2;
}

pub fn gen_universal(io: Io, seed: u64, count: u64) !void {
    const std_out_handle = Io.File.stdout();

    const stdout_buf = try std.heap.page_allocator.alloc(u8, count * 128 + 64);
    defer std.heap.page_allocator.free(stdout_buf);
    var float_buf: [512]u8 = undefined;

    var stdout_buffered = std_out_handle.writer(io, stdout_buf);
    const stdout = &stdout_buffered.interface;

    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const json_head = "{\n    \"pairs\":[\n";
    const json_tail = "    ]\n}\n";
    const entry_mask        = "        {{\"x1\": {d}, \"y1\":{d}, \"x2\": {d}, \"y2\": {d}}},\n";
    const entry_mask_last   = "        {{\"x1\": {d}, \"y1\":{d}, \"x2\": {d}, \"y2\": {d}}}\n";
    try stdout.writeAll(json_head);

    var sum: f64 = 0;
    const sum_coef: f64 = 1.0 / @as(f64, @floatFromInt(count));

    var i = count;
    while(i > 0) {
        const x1 = rand_with_pin(rand, f64, 360.0, 0);
        const y1 = rand_with_pin(rand, f64, 180.0, 0);
        const x2 = rand_with_pin(rand, f64, 360.0, 0);
        const y2 = rand_with_pin(rand, f64, 180.0, 0);

        sum += sum_coef * haverstine(x1, y1, x2, y2, 6372.8);

        const line = if (i != 1)
            try std.fmt.bufPrint(&float_buf, entry_mask, .{ x1, y1, x2, y2 })
        else
            try std.fmt.bufPrint(&float_buf, entry_mask_last, .{ x1, y1, x2, y2 });
        try stdout.writeAll(line);

        i -= 1;
    }

    try stdout.writeAll(json_tail);
    try stdout.flush();

    print("Reference Haverstine sum: {}\n", .{sum});
}

pub fn get_cluster(rand: std.Random, cluster_num: u64) usize {
    return rand.intRangeAtMost(u64, 0, cluster_num - 1);
}

pub fn gen_cluster(io: Io, seed: u64, count: u64) !void {
    const std_out_handle = Io.File.stdout();

    const stdout_buf = try std.heap.page_allocator.alloc(u8, count * 128 + 64);
    defer std.heap.page_allocator.free(stdout_buf);
    var float_buf: [512]u8 = undefined;

    var stdout_buffered = std_out_handle.writer(io, stdout_buf);
    const stdout = &stdout_buffered.interface;

    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const json_head = "{\n    \"pairs\":[\n";
    const json_tail = "    ]\n}\n";
    const entry_mask        = "        {{\"x1\": {d}, \"y1\":{d}, \"x2\": {d}, \"y2\": {d}}},\n";
    const entry_mask_last   = "        {{\"x1\": {d}, \"y1\":{d}, \"x2\": {d}, \"y2\": {d}}}\n";
    try stdout.writeAll(json_head);

    const cluster_num = rand.intRangeAtMost(u64, 1, CLUSTER_NUM_CAP);
    const cluster_range = rand.float(f64) * CLUSTER_RANGE_CAP;

    var i: usize = 0;
    var cluster_pin_points: [CLUSTER_NUM_CAP * 2]f64 = undefined;
    while(i < cluster_num * 2) {
        cluster_pin_points[i] = rand_with_pin(rand, f64, 360, 0);
        cluster_pin_points[i + 1] = rand_with_pin(rand, f64, 180, 0);
        i += 2;
    }

    var sum: f64 = 0;
    const sum_coef: f64 = 1.0 / @as(f64, @floatFromInt(count));

    i = count;
    while(i > 0) {
        const cluster_idx = get_cluster(rand, cluster_num);
        const pin_x = cluster_pin_points[cluster_idx * 2];
        const pin_y = cluster_pin_points[cluster_idx * 2 + 1];

        const x1 = rand_with_pin(rand, f64, cluster_range, pin_x);
        const y1 = rand_with_pin(rand, f64, cluster_range, pin_y);
        const x2 = rand_with_pin(rand, f64, cluster_range, pin_x);
        const y2 = rand_with_pin(rand, f64, cluster_range, pin_y);

        sum += sum_coef * haverstine(x1, y1, x2, y2, 6372.8);

        const line = if (i != 1)
            try std.fmt.bufPrint(&float_buf, entry_mask, .{ x1, y1, x2, y2 })
        else
            try std.fmt.bufPrint(&float_buf, entry_mask_last, .{ x1, y1, x2, y2 });
        try stdout.writeAll(line);

        i -= 1;
    }

    try stdout.writeAll(json_tail);
    try stdout.flush();
    print("Reference Haverstine sum: {}\n", .{sum});

}

pub fn gen(io: Io, g: gen_type, seed: u64, count: u64) !void {
    switch (g) {
        .universal => {
            try gen_universal(io, seed, count);
            return;
        },
        .cluster => {
            try gen_cluster(io, seed, count);
            return;
        }

    }
}

