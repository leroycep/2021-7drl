const std = @import("std");
const tile = @import("./tile.zig");
const math = @import("math");
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;
const render_tile = @import("./main.zig").render_tile;
const Neighbors = tile.Neighbors;
const FlatRenderer = @import("./flat_render.zig").FlatRenderer;

pub const Map = struct {
    allocator: *std.mem.Allocator,
    tiles: []tile.Tag,
    size: Vec2i,
    spawn: Vec2i,

    pub fn init(alloc: *std.mem.Allocator, size: Vec2i) !@This() {
        const tiles = try alloc.alloc(tile.Tag, @intCast(usize, size.x * size.y));
        errdefer allocator.free(tiles);
        std.mem.set(tile.Tag, tiles, .Empty);
        return @This(){
            .allocator = alloc,
            .tiles = tiles,
            .size = size,
            .spawn = vec2i(0, 0),
        };
    }

    pub fn deinit(this: @This()) void {
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

    pub fn render(this: @This(), flatRenderer: *FlatRenderer) void {
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
};
