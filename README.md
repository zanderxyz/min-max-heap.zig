# A Min-Max Heap for Zig

![Tests](https://github.com/zanderxyz/min-max-heap.zig/workflows/Build%20and%20Test/badge.svg)

This is my implementation of a [min-max heap](https://en.wikipedia.org/wiki/Min-max_heap) data structure in Zig. 

The API borrows strongly from the existing [PriorityQueue](https://github.com/ziglang/zig/blob/master/lib/std/priority_queue.zig) in the Zig standard library, and despite the fact that the min-max heap offers O(log n) access to both ends of the structure, it outperforms the Priority Queue (implemented as a binary heap) in many cases.

## Benchmarks

* Compiled with ReleaseSafe mode
* Use an input of N items randomly chosen from the given type (i.e. a random u8 would be >= 0 and < 256). 
* Run on 15 January 2021 using Zig 0.7.1 
* Run on my old 12" Macbook (2017)
* Clearly all these numbers are very rough approximations (removing min and max items from the binary heap should in theory be identical), but the performance differences seem consistent even if the exact times are not precise
* I would expect that on better hardware the min-max heap will outperform by a larger amount, as the CPU is able to parallelise it more at the instruction-level.

See `bench_minmax.zig` and `bench_std.zig` for the code. These were compiled and run many times using [Hyperfine](https://github.com/sharkdp/hyperfine).

### Making a Heap from an array

This should be O(n).

Type | Number of items | Min-Max | Binary | Comparison
--- | --- | --- | --- | ---
u8 | 1,000,000 | 15ms | 27ms | 80% faster
u8 | 10,000,000 | 139ms | 247ms | 77% faster
u64 | 1,000,000 | 36ms | 41ms | 14% faster
u64 | 10,000,000 | 300ms | 360ms | 20% faster

### Adding items one by one

This should be O(n log n)

Type | Number of items | Min-Max | Binary | Comparison
--- | --- | --- | --- | ---
u8 | 1,000,000 | 36ms | 36ms | -
u8 | 10,000,000 | 357ms | 340ms | 5% slower
u64 | 1,000,000 | 64ms | 61ms | 5% slower
u64 | 10,000,000 | 530ms | 515ms | 3% slower

### Removing the smallest item one by one

This should be O(n log n). Note that the benchmark has to make the heap first, so the time to make the heap has been subtracted here.

Type | Number of items | Min-Max | Binary | Comparison
--- | --- | --- | --- | ---
u8 | 1,000,000 | 161ms | 210ms | 30% faster
u8 | 10,000,000 | 2.16s | 2.84s | 31% faster
u64 | 1,000,000 | 381ms | 343ms | 10% slower
u64 | 10,000,000 | 6.13s | 5.45s | 11% slower

### Removing the largest item one by one

For the Min-Max heap, this is exactly the same heap as in the previous example, but for the standard library Priority Queue it is a new data structure (the reverse of the one above). Just as when removing the smallest item, the benchmark has to make the heap first, so the time to make the heap has been subtracted here.

This should be O(n log n).

Type | Number of items | Min-Max | Binary | Comparison
--- | --- | --- | --- | ---
u8 | 1,000,000 | 163ms | 214ms | 31% faster
u8 | 10,000,000 | 2.18s | 2.87s | 32% faster
u64 | 1,000,000 | 361ms | 360ms | -
u64 | 10,000,000 | 5.95s | 5.71s | 4% slower

## License

Copyright (c) 2021 zanderxyz

The source is released under the MIT License.

Check [LICENSE](https://github.com/zanderxyz/min-max-heap.zig/blob/master/LICENSE) for more information.
