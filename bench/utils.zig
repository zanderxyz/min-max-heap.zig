const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;

pub fn lessThanComparison(comptime T: type) fn (a: T, b: T) bool {
    return struct {
        fn lessThan(a: T, b: T) bool {
            return a < b;
        }
    }.lessThan;
}

pub fn greaterThanComparison(comptime T: type) fn (a: T, b: T) bool {
    return struct {
        fn greaterThan(a: T, b: T) bool {
            return a > b;
        }
    }.greaterThan;
}

pub fn runBenchmark(comptime T: type, alloc: *Allocator, rng: *Random, benchmark: anytype) !void {
    const setup = try setupBench(T, alloc, rng);
    const items = setup.items;

    switch (setup.action) {
        .make => {
            var heap = benchmark.make(alloc, items);
            defer heap.deinit();
        },
        .add => {
            var heap = benchmark.new(alloc);
            defer heap.deinit();

            benchmark.add(&heap, items);
        },
        .remove => {
            var heap = benchmark.make(alloc, items);
            defer heap.deinit();

            benchmark.remove(&heap);
        },
        .remove_max => {
            var heap = benchmark.makeMax(alloc, items);
            defer heap.deinit();

            benchmark.removeMax(&heap);
        },
    }
}

fn setupBench(comptime T: type, allocator: *Allocator, rng: *Random) !Setup(T) {
    const args = try getArgs(allocator);
    const items = try generateRandomSlice(T, allocator, rng, args.size);

    return Setup(T){
        .action = args.action,
        .items = items,
    };
}

fn Setup(comptime T: type) type {
    return struct {
        action: Action,
        items: []T,
    };
}

const Args = struct {
    action: Action,
    size: usize,
};

const Action = enum {
    make,
    add,
    remove,
    remove_max,
};

fn getArgs(allocator: *Allocator) !Args {
    var args = std.process.args();

    const arg0 = try args.next(allocator).?;
    defer allocator.free(arg0);

    const arg1 = try args.next(allocator) orelse @panic("Must provide action for benchmark");
    defer allocator.free(arg1);

    const action = std.meta.stringToEnum(Action, arg1) orelse @panic("Action must be: make, add, remove");

    const arg2 = try args.next(allocator) orelse @panic("Must provide number of items for benchmark");
    defer allocator.free(arg2);

    const size = try std.fmt.parseInt(usize, arg2, 10);

    return Args{
        .action = action,
        .size = size,
    };
}

fn generateRandomSlice(comptime T: type, allocator: *std.mem.Allocator, rng: *Random, size: usize) ![]T {
    var array = std.ArrayList(T).init(allocator);
    try array.ensureCapacity(size);

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = rng.int(T);
        try array.append(elem);
    }

    return array.toOwnedSlice();
}
