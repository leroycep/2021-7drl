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
const Map = @import("./map.zig").Map;
const tile = @import("./tile.zig");
const generate = @import("./generate.zig");

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
    map = try generate.generateMap(allocator, .{
        .size = vec2i(50, 50),
        .max_rooms = 50,
        .room_size_range = .{
            .min = 3,
            .max = 10,
        },
    });

    {
        var y: i32 = 0;
        while (y < map.size.y) : (y += 1) {
            map.set(vec2i(0, y), .ThickWallVertical);
            map.set(vec2i(map.size.x - 1, y), .ThickWallVertical);
        }
        var x: i32 = 0;
        while (x < map.size.x) : (x += 1) {
            map.set(vec2i(x, 0), .ThickWallHorizontal);
            map.set(vec2i(x, map.size.y - 1), .ThickWallHorizontal);
        }
        map.set(vec2i(0, 0), .ThickWallDownRight);
        map.set(vec2i(map.size.x - 1, 0), .ThickWallDownLeft);
        map.set(vec2i(map.size.x - 1, map.size.y - 1), .ThickWallUpLeft);
        map.set(vec2i(0, map.size.y - 1), .ThickWallUpRight);
    }
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
            .KP_8, .W, .UP => playerMove = vec2i(0, -1),
            .KP_2, .S, .DOWN => playerMove = vec2i(0, 1),
            .KP_4, .A, .LEFT => playerMove = vec2i(-1, 0),
            .KP_6, .D, .RIGHT => playerMove = vec2i(1, 0),

            .KP_7 => playerMove = vec2i(-1, -1),
            .KP_9 => playerMove = vec2i(1, -1),
            .KP_3 => playerMove = vec2i(1, 1),
            .KP_1 => playerMove = vec2i(-1, 1),
            else => {},
        },
        .Quit => platform.quit(),
        else => {},
    }

    if (!map.getDesc(playerPos.addv(playerMove)).solid) {
        playerPos = playerPos.addv(playerMove);
    }
    playerMove = vec2i(0, 0);
}

pub fn render(alpha: f64) !void {
    const screen_size_int = platform.getScreenSize();
    const screen_size = screen_size_int.intToFloat(f32);

    flatRenderer.setSize(screen_size);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size_int.x, screen_size_int.y);

    map.render();
    render_tile(4, playerPos);
    flatRenderer.flush();
}

pub fn render_tile(id: u16, pos: Vec2i) void {
    const tileposy = id / (TILESET_W / TILE_W);
    const tileposx = id - (tileposy * (TILESET_W / TILE_W));

    const texpos1 = vec2f(@intToFloat(f32, tileposx) / @intToFloat(f32, TILESET_W / TILE_W), @intToFloat(f32, tileposy) / @intToFloat(f32, TILESET_H / TILE_H));
    const texpos2 = vec2f(@intToFloat(f32, tileposx + 1) / @intToFloat(f32, TILESET_W / TILE_W), @intToFloat(f32, tileposy + 1) / @intToFloat(f32, TILESET_H / TILE_H));

    flatRenderer.drawTextureRect(tilesetTex, texpos1, texpos2, pos.scale(16).intToFloat(f32), vec2f(16, 16)) catch unreachable;
}
