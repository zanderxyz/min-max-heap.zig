const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const warn = std.debug.warn;
const Order = std.math.Order;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

/// Min-Max Heap for storing generic data. Initialize with `init`.
pub fn MinMaxHeap(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        len: usize,
        allocator: *Allocator,
        compareFn: fn (a: T, b: T) Order,

        /// Initialize and return a new priority deheap. Provide `compareFn`
        /// that returns `Order.lt` when its first argument should
        /// get min-popped before its second argument, `Order.eq` if the
        /// arguments are of equal priority, or `Order.gt` if the second
        /// argument should be min-popped first. Popping the max element works
        /// in reverse. For example, to make `popMin` return the smallest
        /// number, provide
        ///
        /// `fn lessThan(a: T, b: T) Order { return std.math.order(a, b); }`
        pub fn init(allocator: *Allocator, compareFn: fn (T, T) Order) Self {
            return Self{
                .items = &[_]T{},
                .len = 0,
                .allocator = allocator,
                .compareFn = compareFn,
            };
        }

        /// Free memory used by the deheap.
        pub fn deinit(self: Self) void {
            self.allocator.free(self.items);
        }

        /// Insert a new element, maintaining priority.
        pub fn add(self: *Self, elem: T) !void {
            try ensureCapacity(self, self.len + 1);
            addUnchecked(self, elem);
        }

        /// Add each element in `items` to the deheap.
        pub fn addSlice(self: *Self, items: []const T) !void {
            try self.ensureCapacity(self.len + items.len);
            for (items) |e| {
                self.addUnchecked(e);
            }
        }

        fn addUnchecked(self: *Self, elem: T) void {
            self.items[self.len] = elem;

            if (self.len > 0) {
                const start = self.getStartForSiftUp(elem, self.len);
                self.siftUp(start);
            }

            self.len += 1;
        }

        fn isMinLayer(index: usize) bool {
            // In the min-max heap structure:
            // The first element is on a min layer;
            // next two are on a max layer;
            // next four are on a min layer, and so on.
            const leading_zeros = @clz(usize, index + 1);
            const highest_set_bit = @bitSizeOf(usize) - 1 - leading_zeros;
            return (highest_set_bit & 1) == 0;
        }

        fn nextIsMinLayer(self: Self) bool {
            return isMinLayer(self.len);
        }

        const StartIndexAndLayer = struct {
            index: usize,
            min_layer: bool,
        };

        fn getStartForSiftUp(self: Self, child: T, index: usize) StartIndexAndLayer {
            var child_index = index;
            var parent_index = parentIndex(child_index);
            const parent = self.items[parent_index];

            const min_layer = self.nextIsMinLayer();
            const order = self.compareFn(child, parent);
            if ((min_layer and order == .gt) or (!min_layer and order == .lt)) {
                // We must swap the item with it's parent if it is on the "wrong" layer
                self.items[parent_index] = child;
                self.items[child_index] = parent;
                return .{
                    .index = parent_index,
                    .min_layer = !min_layer,
                };
            } else {
                return .{
                    .index = child_index,
                    .min_layer = min_layer,
                };
            }
        }

        fn siftUp(self: *Self, start: StartIndexAndLayer) void {
            if (start.min_layer) {
                doSiftUp(self, start.index, .lt);
            } else {
                doSiftUp(self, start.index, .gt);
            }
        }

        fn doSiftUp(self: *Self, start_index: usize, target_order: Order) void {
            var child_index = start_index;
            while (child_index > 2) {
                var grandparent_index = grandparentIndex(child_index);
                const child = self.items[child_index];
                const grandparent = self.items[grandparent_index];

                // If the grandparent is already better or equal, we have gone as far as we need to
                if (self.compareFn(child, grandparent) != target_order) break;

                // Otherwise swap the item with it's grandparent
                self.items[grandparent_index] = child;
                self.items[child_index] = grandparent;
                child_index = grandparent_index;
            }
        }

        /// Look at the smallest element in the deheap. Returns
        /// `null` if empty.
        pub fn peekMin(self: *Self) ?T {
            return if (self.len > 0) self.items[0] else null;
        }

        /// Look at the largest element in the deheap. Returns
        /// `null` if empty.
        pub fn peekMax(self: *Self) ?T {
            if (self.len == 0) return null;
            if (self.len == 1) return self.items[0];
            if (self.len == 2) return self.items[1];
            return self.bestItemAtIndices(1, 2, .gt).item;
        }

        fn maxIndex(self: Self) ?usize {
            if (self.len == 0) return null;
            if (self.len == 1) return 0;
            if (self.len == 2) return 1;
            return self.bestItemAtIndices(1, 2, .gt).index;
        }

        /// Pop the smallest element from the deheap. Returns
        /// `null` if empty.
        pub fn removeMinOrNull(self: *Self) ?T {
            return if (self.len > 0) self.removeMin() else null;
        }

        /// Remove and return the smallest element from the
        /// deheap.
        pub fn removeMin(self: *Self) T {
            return self.removeIndex(0);
        }

        /// Pop the largest element from the deheap. Returns
        /// `null` if empty.
        pub fn removeMaxOrNull(self: *Self) ?T {
            return if (self.len > 0) self.removeMax() else null;
        }

        /// Remove and return the largest element from the
        /// deheap.
        pub fn removeMax(self: *Self) T {
            return self.removeIndex(self.maxIndex().?);
        }

        /// Remove and return element at index. Indices are in the
        /// same order as iterator, which is not necessarily priority
        /// order.
        pub fn removeIndex(self: *Self, index: usize) T {
            assert(self.len > index);
            const item = self.items[index];
            const last = self.items[self.len - 1];

            self.items[index] = last;
            self.len -= 1;
            siftDown(self, index);

            return item;
        }

        fn siftDown(self: *Self, index: usize) void {
            if (isMinLayer(index)) {
                self.doSiftDown(index, .lt);
            } else {
                self.doSiftDown(index, .gt);
            }
        }

        fn doSiftDown(self: *Self, start_index: usize, target_order: Order) void {
            var index = start_index;
            const half = self.len >> 1;
            while (true) {
                const first_grandchild_index = firstGrandchildIndex(index);
                const last_grandchild_index = first_grandchild_index + 3;

                const elem = self.items[index];

                if (last_grandchild_index < self.len) {
                    // All four grandchildren exist
                    const index2 = first_grandchild_index + 1;
                    const index3 = index2 + 1;

                    // Find the best grandchild
                    const best_left = self.bestItemAtIndices(first_grandchild_index, index2, target_order);
                    const best_right = self.bestItemAtIndices(index3, last_grandchild_index, target_order);
                    const best_grandchild = self.bestItem(best_left, best_right, target_order);

                    // If the item is better than or equal to its best grandchild, we are done
                    if (self.compareFn(best_grandchild.item, elem) != target_order) return;

                    // Otherwise, swap them
                    self.items[best_grandchild.index] = elem;
                    self.items[index] = best_grandchild.item;
                    index = best_grandchild.index;

                    // We might need to swap the element with it's parent
                    self.swapIfParentIsBetter(elem, index, target_order);
                } else {
                    // The children or grandchildren are the last layer
                    const first_child_index = firstChildIndex(index);
                    if (first_child_index > self.len) return;

                    const best_descendent = self.bestDescendent(first_child_index, first_grandchild_index, target_order);

                    // If the item is better than or equal to its best descendant, we are done
                    if (self.compareFn(best_descendent.item, elem) != target_order) return;

                    // Otherwise swap them
                    self.items[best_descendent.index] = elem;
                    self.items[index] = best_descendent.item;
                    index = best_descendent.index;

                    // If we didn't swap a grandchild, we are done
                    if (index < first_grandchild_index) return;

                    // We might need to swap the element with it's parent
                    self.swapIfParentIsBetter(elem, index, target_order);
                    return;
                }

                // If we are now in the last layer, we are done
                if (index >= half) return;
            }
        }

        fn swapIfParentIsBetter(self: *Self, child: T, child_index: usize, target_order: Order) void {
            const parent_index = parentIndex(child_index);
            const parent = self.items[parent_index];

            if (self.compareFn(parent, child) == target_order) {
                self.items[parent_index] = child;
                self.items[child_index] = parent;
            }
        }

        const ItemAndIndex = struct {
            item: T,
            index: usize,
        };

        fn getItem(self: Self, index: usize) ItemAndIndex {
            return .{
                .item = self.items[index],
                .index = index,
            };
        }

        fn bestItem(self: Self, item1: ItemAndIndex, item2: ItemAndIndex, target_order: Order) ItemAndIndex {
            if (self.compareFn(item1.item, item2.item) == target_order) {
                return item1;
            } else {
                return item2;
            }
        }

        fn bestItemAtIndices(self: Self, index1: usize, index2: usize, target_order: Order) ItemAndIndex {
            var item1 = self.getItem(index1);
            var item2 = self.getItem(index2);
            return self.bestItem(item1, item2, target_order);
        }

        fn bestDescendent(self: Self, first_child_index: usize, first_grandchild_index: usize, target_order: Order) ItemAndIndex {
            const second_child_index = first_child_index + 1;
            if (first_grandchild_index >= self.len) {
                // No grandchildren, find the best child (second may not exist)
                if (second_child_index >= self.len) {
                    return .{
                        .item = self.items[first_child_index],
                        .index = first_child_index,
                    };
                } else {
                    return self.bestItemAtIndices(first_child_index, second_child_index, target_order);
                }
            }

            const second_grandchild_index = first_grandchild_index + 1;
            if (second_grandchild_index >= self.len) {
                // One grandchild, so we know there is a second child. Compare first grandchild and second child
                return self.bestItemAtIndices(first_grandchild_index, second_child_index, target_order);
            }

            const best_left_grandchild_index = self.bestItemAtIndices(first_grandchild_index, second_grandchild_index, target_order).index;
            const third_grandchild_index = second_grandchild_index + 1;
            if (third_grandchild_index >= self.len) {
                // Two grandchildren, and we know the best. Compare this to second child.
                return self.bestItemAtIndices(best_left_grandchild_index, second_child_index, target_order);
            } else {
                // Three grandchildren, compare the min of the first two with the third
                return self.bestItemAtIndices(best_left_grandchild_index, third_grandchild_index, target_order);
            }
        }

        /// Return the number of elements remaining in the deheap
        pub fn count(self: Self) usize {
            return self.len;
        }

        /// Return the number of elements that can be added to the
        /// deheap before more memory is allocated.
        pub fn capacity(self: Self) usize {
            return self.items.len;
        }

        /// Deheap takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// De-initialize with `deinit`.
        pub fn fromOwnedSlice(allocator: *Allocator, compareFn: fn (T, T) Order, items: []T) Self {
            var heap = Self{
                .items = items,
                .len = items.len,
                .allocator = allocator,
                .compareFn = compareFn,
            };

            if (heap.len <= 1) return heap;

            const half = (heap.len >> 1) - 1;
            var i: usize = 0;
            while (i <= half) : (i += 1) {
                const index = half - i;
                heap.siftDown(index);
            }
            return heap;
        }

        pub fn ensureCapacity(self: *Self, new_capacity: usize) !void {
            var better_capacity = self.capacity();
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            self.items = try self.allocator.realloc(self.items, better_capacity);
        }

        /// Reduce allocated capacity to `new_len`.
        pub fn shrinkAndFree(self: *Self, new_len: usize) void {
            assert(new_len <= self.items.len);

            // Cannot shrink to smaller than the current heap size without invalidating the heap property
            assert(new_len >= self.len);

            self.items = self.allocator.realloc(self.items[0..], new_len) catch |e| switch (e) {
                error.OutOfMemory => { // no problem, capacity is still correct then.
                    self.items.len = new_len;
                    return;
                },
            };
            self.len = new_len;
        }

        /// Reduce length to `new_len`.
        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            assert(new_len <= self.items.len);

            // Cannot shrink to smaller than the current heap size without invalidating the heap property
            assert(new_len >= self.len);

            self.len = new_len;
        }

        pub fn update(self: *Self, elem: T, new_elem: T) !void {
            var old_index: usize = std.mem.indexOfScalar(T, self.items[0..self.len], elem) orelse return error.ElementNotFound;
            _ = self.removeIndex(old_index);
            self.addUnchecked(new_elem);
        }

        pub const Iterator = struct {
            heap: *MinMaxHeap(T),
            count: usize,

            pub fn next(it: *Iterator) ?T {
                if (it.count >= it.heap.len) return null;
                const out = it.count;
                it.count += 1;
                return it.heap.items[out];
            }

            pub fn reset(it: *Iterator) void {
                it.count = 0;
            }
        };

        /// Return an iterator that walks the heap without consuming
        /// it. Invalidated if the heap is modified.
        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .heap = self,
                .count = 0,
            };
        }

        fn dump(self: *Self) void {
            warn("{{ ", .{});
            warn("items: ", .{});
            for (self.items) |e, i| {
                if (i >= self.len) break;
                warn("{}, ", .{e});
            }
            warn("array: ", .{});
            for (self.items) |e, i| {
                warn("{}, ", .{e});
            }
            warn("len: {} ", .{self.len});
            warn("capacity: {}", .{self.capacity()});
            warn(" }}\n", .{});
        }

        fn parentIndex(index: usize) usize {
            return (index - 1) >> 1;
        }

        fn grandparentIndex(index: usize) usize {
            return parentIndex(parentIndex(index));
        }

        fn firstChildIndex(index: usize) usize {
            return (index << 1) + 1;
        }

        fn firstGrandchildIndex(index: usize) usize {
            return firstChildIndex(firstChildIndex(index));
        }
    };
}

fn lessThanComparison(a: u32, b: u32) Order {
    return std.math.order(a, b);
}

const Heap = MinMaxHeap(u32);

test "MinMaxHeap: add and remove min" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(54);
    try heap.add(12);
    try heap.add(7);
    try heap.add(23);
    try heap.add(25);
    try heap.add(13);

    expectEqual(@as(u32, 7), heap.removeMin());
    expectEqual(@as(u32, 12), heap.removeMin());
    expectEqual(@as(u32, 13), heap.removeMin());
    expectEqual(@as(u32, 23), heap.removeMin());
    expectEqual(@as(u32, 25), heap.removeMin());
    expectEqual(@as(u32, 54), heap.removeMin());
}

test "MinMaxHeap: add and remove min structs" {
    const S = struct {
        size: u32,
    };
    var heap = MinMaxHeap(S).init(testing.allocator, struct {
        fn order(a: S, b: S) Order {
            return std.math.order(a.size, b.size);
        }
    }.order);
    defer heap.deinit();

    try heap.add(.{ .size = 54 });
    try heap.add(.{ .size = 12 });
    try heap.add(.{ .size = 7 });
    try heap.add(.{ .size = 23 });
    try heap.add(.{ .size = 25 });
    try heap.add(.{ .size = 13 });

    expectEqual(@as(u32, 7), heap.removeMin().size);
    expectEqual(@as(u32, 12), heap.removeMin().size);
    expectEqual(@as(u32, 13), heap.removeMin().size);
    expectEqual(@as(u32, 23), heap.removeMin().size);
    expectEqual(@as(u32, 25), heap.removeMin().size);
    expectEqual(@as(u32, 54), heap.removeMin().size);
}

test "MinMaxHeap: add and remove max" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(54);
    try heap.add(12);
    try heap.add(7);
    try heap.add(23);
    try heap.add(25);
    try heap.add(13);

    expectEqual(@as(u32, 54), heap.removeMax());
    expectEqual(@as(u32, 25), heap.removeMax());
    expectEqual(@as(u32, 23), heap.removeMax());
    expectEqual(@as(u32, 13), heap.removeMax());
    expectEqual(@as(u32, 12), heap.removeMax());
    expectEqual(@as(u32, 7), heap.removeMax());
}

test "MinMaxHeap: add and remove same min" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(1);
    try heap.add(1);
    try heap.add(2);
    try heap.add(2);
    try heap.add(1);
    try heap.add(1);

    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 2), heap.removeMin());
    expectEqual(@as(u32, 2), heap.removeMin());
}

test "MinMaxHeap: add and remove same max" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(1);
    try heap.add(1);
    try heap.add(2);
    try heap.add(2);
    try heap.add(1);
    try heap.add(1);

    expectEqual(@as(u32, 2), heap.removeMax());
    expectEqual(@as(u32, 2), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
}

test "MinMaxHeap: removeOrNull empty" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    expect(heap.removeMinOrNull() == null);
    expect(heap.removeMaxOrNull() == null);
}

test "MinMaxHeap: edge case 3 elements" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(9);
    try heap.add(3);
    try heap.add(2);

    expectEqual(@as(u32, 2), heap.removeMin());
    expectEqual(@as(u32, 3), heap.removeMin());
    expectEqual(@as(u32, 9), heap.removeMin());
}

test "MinMaxHeap: edge case 3 elements max" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(9);
    try heap.add(3);
    try heap.add(2);

    expectEqual(@as(u32, 9), heap.removeMax());
    expectEqual(@as(u32, 3), heap.removeMax());
    expectEqual(@as(u32, 2), heap.removeMax());
}

test "MinMaxHeap: peekMin" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    expect(heap.peekMin() == null);

    try heap.add(9);
    try heap.add(3);
    try heap.add(2);

    expect(heap.peekMin().? == 2);
    expect(heap.peekMin().? == 2);
}

test "MinMaxHeap: peekMax" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    expect(heap.peekMin() == null);

    try heap.add(9);
    try heap.add(3);
    try heap.add(2);

    expect(heap.peekMax().? == 9);
    expect(heap.peekMax().? == 9);
}

test "MinMaxHeap: sift up with odd indices" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |e| {
        try heap.add(e);
    }

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMin());
    }
}

test "MinMaxHeap: sift up with odd indices" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |e| {
        try heap.add(e);
    }

    const sorted_items = [_]u32{ 25, 24, 24, 22, 21, 16, 15, 15, 14, 13, 12, 11, 7, 7, 6, 5, 2, 1 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMax());
    }
}

test "MinMaxHeap: addSlice min" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    try heap.addSlice(items[0..]);

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMin());
    }
}

test "MinMaxHeap: addSlice max" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    try heap.addSlice(items[0..]);

    const sorted_items = [_]u32{ 25, 24, 24, 22, 21, 16, 15, 15, 14, 13, 12, 11, 7, 7, 6, 5, 2, 1 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMax());
    }
}

test "MinMaxHeap: fromOwnedSlice trivial case 0" {
    const items = [0]u32{};
    const heap_items = try testing.allocator.dupe(u32, &items);
    var heap = Heap.fromOwnedSlice(testing.allocator, lessThanComparison, heap_items[0..]);
    defer heap.deinit();
    expectEqual(@as(usize, 0), heap.len);
    expect(heap.removeMinOrNull() == null);
}

test "MinMaxHeap: fromOwnedSlice trivial case 1" {
    const items = [1]u32{1};
    const heap_items = try testing.allocator.dupe(u32, &items);
    var heap = Heap.fromOwnedSlice(testing.allocator, lessThanComparison, heap_items[0..]);
    defer heap.deinit();

    expectEqual(@as(usize, 1), heap.len);
    expectEqual(items[0], heap.removeMin());
    expect(heap.removeMinOrNull() == null);
}

test "MinMaxHeap: fromOwnedSlice" {
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    const heap_items = try testing.allocator.dupe(u32, items[0..]);
    var heap = Heap.fromOwnedSlice(testing.allocator, lessThanComparison, heap_items[0..]);
    defer heap.deinit();

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMin());
    }
}

test "MinMaxHeap: update min heap" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(55);
    try heap.add(44);
    try heap.add(11);
    try heap.update(55, 5);
    try heap.update(44, 4);
    try heap.update(11, 1);
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 4), heap.removeMin());
    expectEqual(@as(u32, 5), heap.removeMin());
}

test "MinMaxHeap: update same min heap" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(1);
    try heap.add(1);
    try heap.add(2);
    try heap.add(2);
    try heap.update(1, 5);
    try heap.update(2, 4);
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 2), heap.removeMin());
    expectEqual(@as(u32, 4), heap.removeMin());
    expectEqual(@as(u32, 5), heap.removeMin());
}

test "MinMaxHeap: update max heap" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(55);
    try heap.add(44);
    try heap.add(11);
    try heap.update(55, 5);
    try heap.update(44, 1);
    try heap.update(11, 4);

    expectEqual(@as(u32, 5), heap.removeMax());
    expectEqual(@as(u32, 4), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
}

test "MinMaxHeap: update same max heap" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(1);
    try heap.add(1);
    try heap.add(2);
    try heap.add(2);
    try heap.update(1, 5);
    try heap.update(2, 4);
    expectEqual(@as(u32, 5), heap.removeMax());
    expectEqual(@as(u32, 4), heap.removeMax());
    expectEqual(@as(u32, 2), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
}

test "MinMaxHeap: iterator" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    var map = std.AutoHashMap(u32, void).init(testing.allocator);
    defer {
        heap.deinit();
        map.deinit();
    }

    const items = [_]u32{ 54, 12, 7, 23, 25, 13 };
    for (items) |e| {
        _ = try heap.add(e);
        _ = try map.put(e, {});
    }

    var it = heap.iterator();
    while (it.next()) |e| {
        _ = map.remove(e);
    }

    expectEqual(@as(usize, 0), map.count());
}

test "MinMaxHeap: remove at index" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(3);
    try heap.add(2);
    try heap.add(1);

    var it = heap.iterator();
    var elem = it.next();
    var idx: usize = 0;
    const two_idx = while (elem != null) : (elem = it.next()) {
        if (elem.? == 2)
            break idx;
        idx += 1;
    } else unreachable;

    expectEqual(heap.removeIndex(two_idx), 2);
    expectEqual(heap.removeMin(), 1);
    expectEqual(heap.removeMin(), 3);
    expectEqual(heap.removeMinOrNull(), null);
}

test "MinMaxHeap: iterator while empty" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    var it = heap.iterator();

    expectEqual(it.next(), null);
}

test "MinMaxHeap: shrinkRetainingCapacity and shrinkAndFree" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.ensureCapacity(4);
    expect(heap.capacity() >= 4);

    try heap.add(1);
    try heap.add(2);
    try heap.add(3);
    expect(heap.capacity() >= 4);
    expectEqual(@as(usize, 3), heap.len);

    heap.shrinkRetainingCapacity(3);
    expect(heap.capacity() >= 4);
    expectEqual(@as(usize, 3), heap.len);

    heap.shrinkAndFree(3);
    expectEqual(@as(usize, 3), heap.capacity());
    expectEqual(@as(usize, 3), heap.len);

    expectEqual(@as(u32, 3), heap.removeMax());
    expectEqual(@as(u32, 2), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
    expect(heap.removeMaxOrNull() == null);
}

test "MinMaxHeap: fuzz testing min" {
    var prng = std.rand.DefaultPrng.init(0x12345678);

    const test_case_count = 100;
    const heap_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMin(&prng.random, heap_size);
    }
}

fn fuzzTestMin(rng: *std.rand.Random, comptime heap_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, heap_size);

    var heap = Heap.fromOwnedSlice(allocator, lessThanComparison, items);
    defer heap.deinit();

    var last_removed: ?u32 = null;
    while (heap.removeMinOrNull()) |next| {
        if (last_removed) |last| {
            expect(last <= next);
        }
        last_removed = next;
    }
}

test "MinMaxHeap: fuzz testing max" {
    var prng = std.rand.DefaultPrng.init(0x87654321);

    const test_case_count = 100;
    const heap_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMax(&prng.random, heap_size);
    }
}

fn fuzzTestMax(rng: *std.rand.Random, heap_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, heap_size);

    var heap = Heap.fromOwnedSlice(testing.allocator, lessThanComparison, items);
    defer heap.deinit();

    var last_removed: ?u32 = null;
    while (heap.removeMaxOrNull()) |next| {
        if (last_removed) |last| {
            expect(last >= next);
        }
        last_removed = next;
    }
}

test "MinMaxHeap: fuzz testing min and max" {
    var prng = std.rand.DefaultPrng.init(0x87654321);

    const test_case_count = 100;
    const heap_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMinMax(&prng.random, heap_size);
    }
}

fn fuzzTestMinMax(rng: *std.rand.Random, heap_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, heap_size);

    var heap = Heap.fromOwnedSlice(allocator, lessThanComparison, items);
    defer heap.deinit();

    var last_min: ?u32 = null;
    var last_max: ?u32 = null;
    var i: usize = 0;
    while (i < heap_size) : (i += 1) {
        if (i % 2 == 0) {
            const next = heap.removeMin();
            if (last_min) |last| {
                expect(last <= next);
            }
            last_min = next;
        } else {
            const next = heap.removeMax();
            if (last_max) |last| {
                expect(last >= next);
            }
            last_max = next;
        }
    }
}

fn generateRandomSlice(allocator: *std.mem.Allocator, rng: *std.rand.Random, size: usize) ![]u32 {
    var array = std.ArrayList(u32).init(allocator);
    try array.ensureCapacity(size);

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = rng.int(u32);
        try array.append(elem);
    }

    return array.toOwnedSlice();
}
