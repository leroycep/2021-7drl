const std = @import("std");
const tile = @import("./tile.zig");
const math = @import("math");
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;
const Map = @import("./map.zig").Map;
const platform = @import("seizer");
const component = @import("./component.zig");

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
    max_monsters_per_room: u64,
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
        platform.randomBytes(std.mem.asBytes(&seed));
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

    // Carve out tunnels
    for (rooms.items) |room, idx| {
        if (idx == 0) continue;

        const prev_room = rooms.items[idx - 1];

        const pos_a = prev_room.pos.addv(prev_room.size.scaleDivFloor(2));
        const pos_b = room.pos.addv(room.size.scaleDivFloor(2));

        if (rand.boolean()) {
            create_h_tunnel(&map, pos_a.x, pos_b.x, pos_a.y);
            create_v_tunnel(&map, pos_a.y, pos_b.y, pos_b.x);

            const center = vec2i(pos_b.x, pos_a.y);
            map.setIfEmpty(center.add(-1, -1), .Wall);
            map.setIfEmpty(center.add(-1, 0), .Wall);
            map.setIfEmpty(center.add(-1, 1), .Wall);
            map.setIfEmpty(center.add(0, -1), .Wall);
            map.setIfEmpty(center.add(0, 1), .Wall);
            map.setIfEmpty(center.add(1, -1), .Wall);
            map.setIfEmpty(center.add(1, 0), .Wall);
            map.setIfEmpty(center.add(1, 1), .Wall);
        } else {
            create_v_tunnel(&map, pos_a.y, pos_b.y, pos_a.x);
            create_h_tunnel(&map, pos_a.x, pos_b.x, pos_b.y);

            const center = vec2i(pos_a.x, pos_b.y);
            map.setIfEmpty(center.add(-1, -1), .Wall);
            map.setIfEmpty(center.add(-1, 0), .Wall);
            map.setIfEmpty(center.add(-1, 1), .Wall);
            map.setIfEmpty(center.add(0, -1), .Wall);
            map.setIfEmpty(center.add(0, 1), .Wall);
            map.setIfEmpty(center.add(1, -1), .Wall);
            map.setIfEmpty(center.add(1, 0), .Wall);
            map.setIfEmpty(center.add(1, 1), .Wall);
        }
    }

    // Carve out rooms
    for (rooms.items) |room, room_idx| {
        var y: i64 = room.pos.y;
        while (y <= room.pos.y + room.size.y) : (y += 1) {
            map.setIfEmpty(vec2i(room.pos.x - 1, y), .Wall);
            map.setIfEmpty(vec2i(room.pos.x + room.size.x + 1, y), .Wall);
        }
        var x: i64 = room.pos.x - 1;
        while (x <= room.pos.x + room.size.x + 1) : (x += 1) {
            map.setIfEmpty(vec2i(x, room.pos.y - 1), .Wall);
            map.setIfEmpty(vec2i(x, room.pos.y + room.size.y + 1), .Wall);
        }

        // Empty room
        var pos = room.pos;
        while (pos.y <= room.pos.y + room.size.y) : (pos.y += 1) {
            pos.x = room.pos.x;
            while (pos.x <= room.pos.x + room.size.x) : (pos.x += 1) {
                map.set(pos, .Floor);
            }
        }

        if (room_idx == rooms.items.len - 1) {
            const pos_in_room = Vec2i{
                .x = rand.intRangeAtMostBiased(i64, 0, room.size.x),
                .y = rand.intRangeAtMostBiased(i64, 0, room.size.y),
            };
            map.set(room.pos.addv(pos_in_room), .StairsDown);
        }

        // Place monsters in room
        const num_monsters = rand.intRangeAtMostBiased(u64, 0, opts.max_monsters_per_room);
        var c: u64 = 0;
        while (c < num_monsters) : (c += 1) {
            const monsterPos = Vec2i{
                .x = room.pos.x + rand.intRangeAtMostBiased(i64, 0, room.size.x),
                .y = room.pos.y + rand.intRangeAtMostBiased(i64, 0, room.size.y),
            };
            // Don't place the monster on unwalkable terrain  or stairs
            const tile_tag = map.get(monsterPos);
            if (tile_tag.solid() or tile_tag == .StairsDown) continue;
            createRatEntity(&map, monsterPos);
        }
    }

    map.spawn = rooms.items[0].pos.addv(rooms.items[0].size.scaleDivFloor(2));

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

fn create_h_tunnel(map: *Map, x0: i64, x1: i64, y: i64) void {
    const startx = if (x0 < x1) x0 else x1;
    const endx = if (x0 < x1) x1 else x0;

    var x = startx;
    while (x <= endx) : (x += 1) {
        map.setIfEmpty(vec2i(x, y - 1), .Wall);
        map.setIfEmpty(vec2i(x, y + 1), .Wall);
        if (map.get(vec2i(x, y)) != .Floor) {
            map.set(vec2i(x, y), .Floor);
        }
    }
}

fn create_v_tunnel(map: *Map, y0: i64, y1: i64, x: i64) void {
    const starty = if (y0 < y1) y0 else y1;
    const endy = if (y0 < y1) y1 else y0;

    var y = starty;
    while (y <= endy) : (y += 1) {
        map.setIfEmpty(vec2i(x - 1, y), .Wall);
        map.setIfEmpty(vec2i(x + 1, y), .Wall);
        if (map.get(vec2i(x, y)) != .Floor) {
            map.set(vec2i(x, y), .Floor);
        }
    }
}

pub fn createRatEntity(map: *Map, pos: Vec2i) void {
    var e = map.registry.create();
    map.registry.add(e, component.Position{ .pos = pos });
    map.registry.add(e, component.Render{ .tid = 415 });
    map.registry.add(e, component.Fighter{
        .name = "rat",
        .health = 1,
        .healthMax = 1,
        .power = 1,
        .defense = 0,
    });
}

pub fn corpse(map: *Map, pos: Vec2i) void {
    var e = map.registry.create();
    map.registry.add(e, component.Position{ .pos = pos });
    map.registry.add(e, component.Render{ .tid = 720 });
}
