const std = @import("std");
const platform = @import("platform");
const gl = platform.gl;
const testing = std.testing;
const FlatRenderer = @import("./flat_render.zig").FlatRenderer;
const zigimg = @import("zigimg");
const math = @import("math");
const vec2f = math.Vec(2, f32).init;
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;
const Texture = @import("./texture.zig").Texture;

// Setup environment
pub const panic = platform.panic;
pub const log = platform.log;
pub usingnamespace if (std.builtin.os.tag == .freestanding)
    struct {
        pub const os = struct {
            pub const bits = struct {
                pub const fd_t = void;
            };
        };
    }
else
    struct {};

pub fn main() void {
    platform.run(.{
        .init = onInit,
        .deinit = onDeinit,
        .event = onEvent,
        .render = render,
        .window = .{
            .title = "2021 7 Day Roguelike",
        },
    });
}

// Constants
const TILESET_W = 112;
const TILESET_H = 80;
const TILE_W = 8;
const TILE_H = 8;

// Global variables
var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = (std.builtin.os.tag != .freestanding) }){};
const allocator = &gpa.allocator;

var tilesetTex: Texture = undefined;
var flatRenderer: FlatRenderer = undefined;
var map: Map = undefined;
var playerPos = vec2i(10, 10);
var playerMove = vec2i(0, 0);

pub fn onInit() !void {
    std.log.info("app init", .{});

    var load_tileset = async Texture.initFromFile(allocator, "colored_tilemap_packed.png");

    // == Load tileset
    tilesetTex = try await load_tileset;

    // == Initialize renderer
    flatRenderer = try FlatRenderer.init(allocator, platform.getScreenSize().intToFloat(f32));

    // Create map
    map = try Map.init(allocator, vec2i(30, 30));
    map.set(vec2i(0, 0), 1);
    map.set(vec2i(1, 0), 1);
    map.set(vec2i(2, 0), 1);
    map.set(vec2i(3, 0), 1);
    map.set(vec2i(4, 0), 1);

    map.set(vec2i(0, 4), 1);
    map.set(vec2i(1, 4), 1);
    map.set(vec2i(2, 4), 1);
    map.set(vec2i(3, 4), 1);
    map.set(vec2i(4, 4), 1);

    map.set(vec2i(0, 1), 1);
    map.set(vec2i(0, 2), 1);
    map.set(vec2i(0, 3), 1);
    map.set(vec2i(0, 4), 1);

    map.set(vec2i(4, 1), 1);
    map.set(vec2i(4, 2), 1);
    map.set(vec2i(4, 3), 1);
    map.set(vec2i(4, 4), 1);
}

fn onDeinit() void {
    std.log.info("app deinit", .{});
    map.deinit();
    flatRenderer.deinit();
    _ = gpa.deinit();
}

pub fn onEvent(event: platform.event.Event) !void {
    switch (event) {
        .KeyDown => |e| switch (e.scancode) {
            .UP => playerMove = vec2i(0, -1),
            .DOWN => playerMove = vec2i(0, 1),
            .LEFT => playerMove = vec2i(-1, 0),
            .RIGHT => playerMove = vec2i(1, 0),

            .KP_8 => playerMove = vec2i(0, -1),
            .KP_2 => playerMove = vec2i(0, 1),
            .KP_4 => playerMove = vec2i(-1, 0),
            .KP_6 => playerMove = vec2i(1, 0),

            .KP_7 => playerMove = vec2i(-1, -1),
            .KP_9 => playerMove = vec2i(1, -1),
            .KP_3 => playerMove = vec2i(1, 1),
            .KP_1 => playerMove = vec2i(-1, 1),
            else => {},
        },
        .Quit => platform.quit(),
        else => {},
    }

    if (map.get(playerPos.addv(playerMove)) == 0) {
        playerPos = playerPos.addv(playerMove);
    }
    playerMove = vec2i(0, 0);
}

pub fn render(alpha: f64) !void {
    const screen_size_int = platform.getScreenSize();
    const screen_size = screen_size_int.intToFloat(f32);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size_int.x, screen_size_int.y);

    map.render();
    render_tile(4, playerPos);
    flatRenderer.flush();
}

fn render_tile(id: u16, pos: Vec2i) void {
    const tileposy = id / (TILESET_W / TILE_W);
    const tileposx = id - (tileposy * (TILESET_W / TILE_W));

    const texpos1 = vec2f(@intToFloat(f32, tileposx) / @intToFloat(f32, TILESET_W / TILE_W), @intToFloat(f32, tileposy) / @intToFloat(f32, TILESET_H / TILE_H));
    const texpos2 = vec2f(@intToFloat(f32, tileposx + 1) / @intToFloat(f32, TILESET_W / TILE_W), @intToFloat(f32, tileposy + 1) / @intToFloat(f32, TILESET_H / TILE_H));

    flatRenderer.drawTextureRect(tilesetTex, texpos1, texpos2, pos.scale(16).intToFloat(f32), vec2f(16, 16)) catch unreachable;
}

const Map = struct {
    allocator: *std.mem.Allocator,
    tiles: []u16,
    size: Vec2i,

    pub fn init(alloc: *std.mem.Allocator, size: Vec2i) !@This() {
        const tiles = try alloc.alloc(u16, @intCast(usize, size.x * size.y));
        errdefer allocator.free(tiles);
        std.mem.set(u16, tiles, 0);
        return @This(){
            .allocator = alloc,
            .tiles = tiles,
            .size = size,
        };
    }

    pub fn deinit(this: @This()) void {
        this.allocator.free(this.tiles);
    }

    pub fn tileIdx(this: @This(), pos: Vec2i) usize {
        return @intCast(usize, pos.y * this.size.x + pos.x);
    }

    pub fn set(this: *@This(), pos: Vec2i, tile: u16) void {
        const idx = this.tileIdx(pos);
        this.tiles[idx] = tile;
    }

    pub fn get(this: @This(), pos: Vec2i) u16 {
        if (pos.x < 0 or pos.x >= this.size.x or pos.y < 0 or pos.y >= this.size.y) return 0;
        const idx = this.tileIdx(pos);
        return this.tiles[idx];
    }

    pub fn render(this: @This()) void {
        var pos = vec2i(0, 0);
        while (pos.y < this.size.y) : (pos.y += 1) {
            pos.x = 0;
            while (pos.x < this.size.x) : (pos.x += 1) {
                switch (this.tiles[this.tileIdx(pos)]) {
                    0 => render_tile(15, pos),
                    1 => {
                        const up = this.get(pos.add(0, -1)) == 1;
                        const down = this.get(pos.add(0, 1)) == 1;
                        const right = this.get(pos.add(1, 0)) == 1;
                        const left = this.get(pos.add(-1, 0)) == 1;
                        if (up and down and left and right) {
                            render_tile(85, pos);
                        } else if (up and right) {
                            render_tile(132, pos);
                        } else if (up and left) {
                            render_tile(135, pos);
                        } else if (down and right) {
                            render_tile(126, pos);
                        } else if (down and left) {
                            render_tile(129, pos);
                        } else if (up or down) {
                            render_tile(130, pos);
                        } else {
                            render_tile(127, pos);
                        }
                    },
                    else => {},
                }
            }
        }
    }
};
