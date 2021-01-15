const std = @import("std");
const Allocator = std.mem.Allocator;
const PriorityQueue = std.PriorityQueue;
const utils = @import("bench/utils.zig");

const Type = u64;
const Heap = PriorityQueue(Type);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = &gpa.allocator;

    var prng = std.rand.DefaultPrng.init(0x87654321);

    try utils.runBenchmark(Type, alloc, &prng.random, Benchmark{});
}

const lessThanComparison = comptime utils.lessThanComparison(Type);
const greaterThanComparison = comptime utils.greaterThanComparison(Type);

const Benchmark = struct {
    const Self = @This();

    pub fn make(self: Self, allocator: *Allocator, items: []Type) Heap {
        return Heap.fromOwnedSlice(allocator, lessThanComparison, items);
    }

    pub fn makeMax(self: Self, allocator: *Allocator, items: []Type) Heap {
        return Heap.fromOwnedSlice(allocator, greaterThanComparison, items);
    }

    pub fn new(self: Self, allocator: *Allocator) Heap {
        return Heap.init(allocator, lessThanComparison);
    }

    pub fn add(self: Self, heap: *Heap, items: []Type) void {
        for (items) |e| {
            heap.add(e) catch unreachable;
        }
    }

    pub fn remove(self: Self, heap: *Heap) void {
        while (heap.removeOrNull()) |next| {}
    }

    pub fn removeMax(self: Self, heap: *Heap) void {
        while (heap.removeOrNull()) |next| {}
    }
};
