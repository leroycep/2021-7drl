const std = @import("std");
const tile = @import("./tile.zig");
const math = @import("math");
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;
const Map = @import("./map.zig").Map;

const Room = struct {
    pos: Vec2i,
    size: Vec2i,

    pub fn overlaps(this: @This(), other: @This()) bool {
        // Add 3, as rooms also include their walls
        return this.pos.x <= other.pos.x + other.size.x + 3 and
            this.pos.y <= other.pos.y + other.size.y + 3 and
            this.pos.x + this.size.x + 3 >= other.pos.x and
            this.pos.y + this.size.y + 3 >= other.pos.y;
    }
};

pub const Options = struct {
    size: Vec2i,
    max_rooms: u64,
    seed: ?u64 = null,
    room_size_range: struct {
        min: i64,
        max: i64,
    },
};

pub fn generateMap(allocator: *std.mem.Allocator, opts: Options) !Map {
    std.debug.assert(opts.size.x > 0 and opts.size.y > 0);
    std.debug.assert(opts.room_size_range.min > 0 and opts.room_size_range.max > 0);

    var map = try Map.init(allocator, opts.size);
    errdefer map.deinit();

    var rooms = std.ArrayList(Room).init(allocator);
    defer rooms.deinit();

    var seed: u64 = undefined;
    if (opts.seed) |seed_given| {
        seed = seed_given;
    } else {
        std.crypto.random.bytes(std.mem.asBytes(&seed));
    }

    var rng = std.rand.DefaultPrng.init(seed);
    var rand = &rng.random;

    // Generate rooms
    {
        var i: u64 = 0;
        while (i < opts.max_rooms) : (i += 1) {
            const size = Vec2i{
                .x = rand.intRangeLessThanBiased(i64, opts.room_size_range.min, opts.room_size_range.max),
                .y = rand.intRangeLessThanBiased(i64, opts.room_size_range.min, opts.room_size_range.max),
            };
            const room = Room{
                .pos = Vec2i{
                    .x = rand.intRangeLessThanBiased(i64, 1, opts.size.x - 1 - size.x),
                    .y = rand.intRangeLessThanBiased(i64, 1, opts.size.y - 1 - size.y),
                },
                .size = size,
            };
            if (overlaps(rooms.items, room)) {
                continue;
            }
            try rooms.append(room);
        }
    }

    // Put rooms into the tile map
    for (rooms.items) |room| {
        var y: i64 = room.pos.y;
        while (y <= room.pos.y + room.size.y) : (y += 1) {
            map.set(vec2i(room.pos.x - 1, y), .ThickWall);
            map.set(vec2i(room.pos.x + room.size.x + 1, y), .ThickWall);
        }
        var x: i64 = room.pos.x - 1;
        while (x <= room.pos.x + room.size.x + 1) : (x += 1) {
            map.set(vec2i(x, room.pos.y - 1), .ThickWall);
            map.set(vec2i(x, room.pos.y + room.size.y + 1), .ThickWall);
        }
    }

    return map;
}

fn overlaps(rooms: []const Room, probe: Room) bool {
    for (rooms) |room, idx| {
        if (probe.overlaps(room)) {
            return true;
        }
    }
    return false;
}
