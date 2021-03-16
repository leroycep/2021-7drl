const std = @import("std");
const tile = @import("./tile.zig");
const math = @import("math");
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;
const render_tile = @import("./main.zig").render_tile;
const Neighbors = tile.Neighbors;
const FlatRenderer = @import("./flat_render.zig").FlatRenderer;
const ArrayDeque = @import("./array_deque.zig").ArrayDeque;
const ecs = @import("ecs");
const component = @import("./component.zig");

pub const Map = struct {
    allocator: *std.mem.Allocator,
    tiles: []tile.Tag,
    size: Vec2i,
    spawn: Vec2i,
    explored: std.AutoArrayHashMap(Vec2i, void),
    visible: std.AutoArrayHashMap(Vec2i, void),
    registry: ecs.Registry,

    pub fn init(alloc: *std.mem.Allocator, size: Vec2i) !@This() {
        const tiles = try alloc.alloc(tile.Tag, @intCast(usize, size.x * size.y));
        errdefer allocator.free(tiles);
        std.mem.set(tile.Tag, tiles, .Empty);
        return @This(){
            .allocator = alloc,
            .tiles = tiles,
            .size = size,
            .spawn = vec2i(0, 0),
            .explored = std.AutoArrayHashMap(Vec2i, void).init(alloc),
            .visible = std.AutoArrayHashMap(Vec2i, void).init(alloc),
            .registry = ecs.Registry.init(alloc),
        };
    }

    pub fn deinit(this: *@This()) void {
        this.registry.deinit();
        this.visible.deinit();
        this.explored.deinit();
        this.allocator.free(this.tiles);
    }

    pub fn tileIdx(this: @This(), pos: Vec2i) usize {
        return @intCast(usize, pos.y * this.size.x + pos.x);
    }

    pub fn set(this: *@This(), pos: Vec2i, tag: tile.Tag) void {
        const idx = this.tileIdx(pos);
        this.tiles[idx] = tag;
    }

    pub fn setIfEmpty(this: *@This(), pos: Vec2i, tag: tile.Tag) void {
        const idx = this.tileIdx(pos);
        if (this.tiles[idx] == .Empty) {
            this.tiles[idx] = tag;
        }
    }

    pub fn get(this: @This(), pos: Vec2i) tile.Tag {
        if (pos.x < 0 or pos.x >= this.size.x or pos.y < 0 or pos.y >= this.size.y) return .Empty;
        const idx = this.tileIdx(pos);
        return this.tiles[idx];
    }

    pub fn getEntityAtPos(this: *@This(), posToCheck: Vec2i) ?ecs.Entity {
        var view = this.registry.view(.{component.Position}, .{});
        for (view.data()) |entity| {
            const pos = view.getConst(entity);
            if (pos.pos.eql(posToCheck)) {
                return entity;
            }
        }

        return null;
    }

    pub fn updateAI(this: *@This()) !void {
        var fov = std.AutoArrayHashMap(Vec2i, void).init(this.allocator);
        defer fov.deinit();

        // Only target player controlled entities for now
        var target_view = this.registry.view(.{ component.PlayerControl, component.Position, component.Fighter }, .{});

        var view = this.registry.view(.{ component.AIControl, component.Position, component.Fighter }, .{});
        var iter = view.iterator();
        while (iter.next()) |entity| {
            fov.clearRetainingCapacity();
            const ai = view.get(component.AIControl, entity);
            switch (ai.*) {
                .Basic => |info| {
                    const position = view.get(component.Position, entity);
                    const fighter = view.getConst(component.Fighter, entity);
                    try this.computeFOV(&fov, position.pos, info.sight);

                    var target: ?ecs.Entity = null;
                    var target_iter = target_view.iterator();
                    while (target_iter.next()) |target_entity| {
                        const target_position = target_view.getConst(component.Position, target_entity);
                        const target_fighter = target_view.get(component.Fighter, target_entity);
                        if (fov.get(target_position.pos) != null) {
                            // TODO: get path to and judge distance
                            const path = this.getPathTo(position.pos, target_position.pos) catch continue;
                            defer this.allocator.free(path);
                            if (path[1].eql(target_position.pos)) {
                                _ = fighter.attack(this, target_entity, target_fighter);
                            } else {
                                position.pos = path[0];
                            }
                        }
                    }
                },
            }
        }
    }

    pub fn render(this: @This(), flatRenderer: *FlatRenderer) void {
        for (this.explored.items()) |entry| {
            const pos = entry.key;
            const tag = this.get(pos);
            const opacity = if (this.visible.get(pos)) |not_null| @as(f32, 1) else 0.5;
            switch (tag.rendering()) {
                .None => {},
                .Static => |tid| render_tile(flatRenderer, tid, pos, opacity),
                .Connected => |tids| {
                    const neighbors = Neighbors{
                        .n = this.get(pos.add(0, -1)) == tag,
                        .e = this.get(pos.add(1, 0)) == tag,
                        .s = this.get(pos.add(0, 1)) == tag,
                        .w = this.get(pos.add(-1, 0)) == tag,
                    };
                    const idx: usize = switch (neighbors.toConnection()) {
                        .None => 0,
                        .North => 1,
                        .East => 2,
                        .South => 3,
                        .West => 4,
                        .NorthSouth, .NorthSouthEast, .NorthSouthWest, .NorthSouthEastWest => 5,
                        .NorthEast => 6,
                        .NorthWest => 7,
                        .SouthEast => 8,
                        .SouthWest => 9,
                        .EastWest, .NorthEastWest, .SouthEastWest => 10,
                    };
                    render_tile(flatRenderer, tids[idx], pos, opacity);
                },
            }
        }

        if (false) {
            var pos = vec2i(0, 0);
            while (pos.y < this.size.y) : (pos.y += 1) {
                pos.x = 0;
                while (pos.x < this.size.x) : (pos.x += 1) {
                    const tag = this.tiles[this.tileIdx(pos)];
                    const desc = tile.DESCRIPTIONS[@enumToInt(tag)];
                    switch (desc.render) {
                        .None => {},
                        .Static => |tid| render_tile(flatRenderer, tid, pos),
                        .Connected => |tids| {
                            const neighbors = Neighbors{
                                .n = this.get(pos.add(0, -1)) == tag,
                                .e = this.get(pos.add(1, 0)) == tag,
                                .s = this.get(pos.add(0, 1)) == tag,
                                .w = this.get(pos.add(-1, 0)) == tag,
                            };
                            const idx: usize = switch (neighbors.toConnection()) {
                                .None => 0,
                                .North => 1,
                                .East => 2,
                                .South => 3,
                                .West => 4,
                                .NorthSouth, .NorthSouthEast, .NorthSouthWest, .NorthSouthEastWest => 5,
                                .NorthEast => 6,
                                .NorthWest => 7,
                                .SouthEast => 8,
                                .SouthWest => 9,
                                .EastWest, .NorthEastWest, .SouthEastWest => 10,
                            };
                            render_tile(flatRenderer, tids[idx], pos);
                        },
                    }
                }
            }
        }
    }

    pub fn computeFOV(this: @This(), fov: *std.AutoArrayHashMap(Vec2i, void), startingPos: Vec2i, radius: i64) !void {
        var positions_to_check = ArrayDeque(Vec2i).init(this.allocator);
        defer positions_to_check.deinit();
        try positions_to_check.push_back(startingPos);

        while (positions_to_check.pop_front()) |pos| {
            const dist = pos.distance(startingPos);
            if (dist > radius) {
                continue;
            }

            try fov.put(pos, .{});

            const tile_tag = this.get(pos);
            if (!tile_tag.transparent()) continue;

            const DIRECTIONS = [_]Vec2i{
                vec2i(-1, -1),
                vec2i(0, -1),
                vec2i(1, -1),
                vec2i(-1, 0),
                vec2i(0, 0),
                vec2i(1, 0),
                vec2i(-1, 1),
                vec2i(0, 1),
                vec2i(1, 1),
            };

            for (DIRECTIONS) |dir| {
                const new_pos = pos.addv(dir);
                if (new_pos.distance(startingPos) > dist) {
                    try positions_to_check.push_back(new_pos);
                }
            }
        }
    }

    pub fn getPathTo(this: @This(), startingPos: Vec2i, endPos: Vec2i) ![]Vec2i {
        // TODO: change to function expression when https://github.com/ziglang/zig/issues/1717 is done
        const util = struct {
            fn h(pos: Vec2i, dest: Vec2i) i64 {
                return pos.distanceSq(dest);
            }
        };
        const h = util.h;

        const Node = struct {
            score: i64,
            pos: Vec2i,

            pub fn cmp(a: @This(), b: @This()) bool {
                return a.score < b.score;
            }
        };

        var came_from = std.AutoHashMap(Vec2i, Vec2i).init(this.allocator);
        defer came_from.deinit();

        var g_score = std.AutoHashMap(Vec2i, i64).init(this.allocator);
        defer g_score.deinit();
        try g_score.put(startingPos, 0);

        var f_score = std.AutoHashMap(Vec2i, i64).init(this.allocator);
        defer f_score.deinit();
        try f_score.put(startingPos, h(startingPos, endPos));

        var positions_to_check = std.PriorityQueue(Node).init(this.allocator, Node.cmp);
        defer positions_to_check.deinit();
        try positions_to_check.add(.{
            .score = f_score.get(startingPos).?,
            .pos = startingPos,
        });

        while (positions_to_check.count() > 0) {
            const node = positions_to_check.remove();

            if (node.pos.eql(endPos)) {
                var total_path = std.ArrayList(Vec2i).init(this.allocator);
                defer total_path.deinit();

                var current_pos = endPos;
                try total_path.append(current_pos);
                while (!current_pos.eql(startingPos)) {
                    current_pos = came_from.get(current_pos).?;
                    try total_path.append(current_pos);
                }
                return total_path.toOwnedSlice();
            }

            const NEIGHBOR_DIR = [_]Vec2i{
                vec2i(-1, -1),
                vec2i(0, -1),
                vec2i(1, -1),
                vec2i(-1, 0),
                vec2i(1, 0),
                vec2i(-1, 1),
                vec2i(0, 1),
                vec2i(1, 1),
            };

            for (NEIGHBOR_DIR) |dir| {
                const neighbor = node.pos.addv(dir);
                if (this.get(neighbor).solid()) {
                    continue;
                }

                const tenative_g_score = g_score.get(node.pos).? + 1;
                const neighbor_g_score = g_score.get(node.pos) orelse std.math.maxInt(i64);
                if (tenative_g_score < neighbor_g_score) {
                    try came_from.put(neighbor, node.pos);
                    try g_score.put(neighbor, tenative_g_score);

                    const neighbor_f_score = tenative_g_score + h(neighbor, endPos);
                    if (f_score.get(node.pos)) |prev_neighbor_f_score| {
                        try positions_to_check.update(.{ .pos = neighbor, .score = prev_neighbor_f_score }, .{ .pos = neighbor, .score = neighbor_f_score });
                    } else {
                        try positions_to_check.add(.{ .pos = neighbor, .score = neighbor_f_score });
                    }
                    try f_score.put(neighbor, neighbor_f_score);
                }
            }
        }

        return error.PathNotFound;
    }
};
