const std = @import("std");
const assert = std.debug.assert;

/// Provides FIFO (First-In First-Out) queue. `push` and `pop` are O(1) amortized.
pub fn ArrayDeque(comptime T: type) type {
    return struct {
        alloc: *std.mem.Allocator,
        buffer: []T,
        head: usize,
        tail: usize,

        pub fn init(alloc: *std.mem.Allocator) @This() {
            return .{
                .alloc = alloc,
                .buffer = &[0]T{},
                .head = 0,
                .tail = 0,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.alloc.free(self.buffer);
        }

        pub fn push_back(self: *@This(), data: T) !void {
            try self.ensureCapacity(self.len() + 1);
            var next = self.head + 1;

            if (next >= self.buffer.len) {
                next = 0;
            }

            if (next == self.tail) {
                return error.BufferOverflow;
            }

            self.buffer[self.head] = data;
            self.head = next;
        }

        pub fn pop_front(self: *@This()) ?T {
            if (self.head == self.tail) {
                return null;
            }

            var next = self.tail + 1;
            if (next >= self.buffer.len) {
                next = 0;
            }

            defer self.tail = next;
            return self.buffer[self.tail];
        }

        pub fn discard_front(self: *@This(), amount_wanted: usize) void {
            if (self.head == self.tail) {
                return;
            }

            const amount = std.math.min(self.len(), amount_wanted);

            var next = self.tail + amount;
            if (next >= self.buffer.len) {
                next -= self.buffer.len;
            }

            self.tail = next;
        }

        pub fn idx(self: *const @This(), i: usize) ?T {
            if (i >= self.buffer.len) {
                return null;
            }
            const j = (self.tail + i) % self.buffer.len;
            if (j < self.head or j >= self.tail) {
                return self.buffer[j];
            }
            return null;
        }

        pub fn idxMut(self: *const @This(), i: usize) ?*T {
            if (i >= self.buffer.len) {
                return null;
            }
            const j = (self.tail + i) % self.buffer.len;
            if (j < self.head or j >= self.tail) {
                return &self.buffer[j];
            }
            return null;
        }

        pub fn len(self: *@This()) usize {
            if (self.head == self.tail) {
                return 0;
            } else if (self.head > self.tail) {
                return self.head - self.tail;
            } else {
                return self.buffer.len - self.tail + self.head;
            }
        }

        pub fn capacity(self: *@This()) usize {
            if (self.buffer.len == 0) {
                return 0;
            } else {
                return self.buffer.len - 1;
            }
        }

        pub fn ensureCapacity(self: *@This(), new_capacity: usize) !void {
            var better_capacity = self.capacity();
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }

            if (self.head < self.tail) {
                // The buffer is split, we need to copy each half to the new buffer
                const old_buffer = self.buffer;
                defer self.alloc.free(old_buffer);
                const tail = self.tail;
                const head = self.head;
                const end = old_buffer.len;

                self.buffer = try self.alloc.alloc(T, better_capacity);
                std.mem.copy(T, self.buffer[0 .. end - tail], old_buffer[tail..end]);
                std.mem.copy(T, self.buffer[end - tail ..], old_buffer[0..head]);
                self.head = head + end - tail;
                self.tail = 0;
            } else {
                self.buffer = try self.alloc.realloc(self.buffer, better_capacity);
            }
        }
    };
}

test "pop() gives back results in FIFO order" {
    var ring = ArrayDeque(i32).init(std.testing.allocator);
    defer ring.deinit();

    try ring.push(1);
    try ring.push(2);
    try ring.push(3);

    assert(ring.head == 3);

    assert(ring.idx(0).? == 1);
    assert(ring.idx(1).? == 2);
    assert(ring.idx(2).? == 3);

    assert(ring.pop().? == 1);
    assert(ring.pop().? == 2);
    assert(ring.pop().? == 3);
    assert(ring.pop() == null);
}

test "buffer wraps around" {
    var ring = ArrayDeque(i32).init(std.testing.allocator);
    defer ring.deinit();

    try ring.ensureCapacity(1);
    const amt = ring.capacity() - 1;

    var i: i32 = 0;
    while (i < amt) : (i += 1) {
        try ring.push(i);
    }

    i = 0;
    while (i < amt) : (i += 1) {
        assert(std.meta.eql(ring.pop(), i));
    }

    i = 0;
    while (i < amt) : (i += 1) {
        try ring.push(i);
    }

    assert(ring.head == (2 * amt % ring.capacity()) - 1);

    i = 0;
    while (i < amt) : (i += 1) {
        std.debug.assert(std.meta.eql(ring.pop(), i));
    }
    assert(ring.pop() == null);
}

test "dynamic allocation does not mess up split array" {
    var ring = ArrayDeque(usize).init(std.testing.allocator);
    defer ring.deinit();

    try ring.ensureCapacity(1);
    const amt = ring.capacity() + 1;

    // Set head and tail to middle of array
    ring.head = @divFloor(ring.capacity(), 2);
    ring.tail = @divFloor(ring.capacity(), 2);

    var i: usize = 0;
    while (i < amt) : (i += 1) {
        try ring.push(i);
    }

    assert(ring.len() == amt);
    i = 0;
    while (i < amt) : (i += 1) {
        assert(std.meta.eql(ring.idx(i), i));
    }
}
