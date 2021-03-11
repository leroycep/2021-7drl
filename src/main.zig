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
const Mat4f = math.Mat4(f32);
const Font = @import("./font_render.zig").BitmapFontRenderer;

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
const TILE_W = 16;
const TILE_H = 16;

// Global variables
var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = (std.builtin.os.tag != .freestanding) }){};
const allocator = &gpa.allocator;

var tilesetTex: Texture = undefined;
var flatRenderer: FlatRenderer = undefined;
var font: Font = undefined;
var map: Map = undefined;
var playerPos = vec2i(10, 10);
var playerMove = vec2i(0, 0);

pub fn onInit() !void {
    std.log.info("app init", .{});

    var load_tileset = async Texture.initFromFile(allocator, "colored_packed.png");
    var load_font = async Font.initFromFile(allocator, "PressStart2P_8.fnt");

    // == Load tileset
    tilesetTex = try await load_tileset;

    // == Initialize renderer
    flatRenderer = try FlatRenderer.init(allocator, platform.getScreenSize().intToFloat(f32));

    font = try await load_font;

    // Create map
    map = try generate.generateMap(allocator, .{
        .size = vec2i(50, 50),
        .max_rooms = 50,
        .room_size_range = .{
            .min = 3,
            .max = 10,
        },
    });

    playerPos = map.spawn;
}

fn onDeinit() void {
    std.log.info("app deinit", .{});
    map.deinit();
    font.deinit();
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

    if (map.get(playerPos) == .StairsDown) {
        map.deinit();

        // Create map
        map = try generate.generateMap(allocator, .{
            .size = vec2i(50, 50),
            .max_rooms = 50,
            .room_size_range = .{
                .min = 3,
                .max = 10,
            },
        });

        playerPos = map.spawn;
    }
}

pub fn render(alpha: f64) !void {
    const screen_size = platform.getScreenSize();

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    const cam_size = screen_size.intToFloat(f32);
    const cam_pos = playerPos.scale(16).intToFloat(f32).subv(cam_size.scaleDiv(2));

    flatRenderer.perspective = Mat4f.orthographic(cam_pos.x, cam_pos.x + cam_size.x, cam_pos.y + cam_size.y, cam_pos.y, -1, 1);
    map.render(&flatRenderer);
    render_tile(&flatRenderer, .{ .pos = 25 }, playerPos);
    flatRenderer.flush();

    flatRenderer.perspective = Mat4f.orthographic(0, cam_size.x, cam_size.y, 0, -1, 1);
    try font.drawText(&flatRenderer, "Hello!", vec2f(10, 10), .{});
    flatRenderer.flush();
}

pub fn render_tile(fr: *FlatRenderer, tid: tile.TID, pos: Vec2i) void {
    const id = tid.pos;

    const tileposy = id / (tilesetTex.size.x / TILE_W);
    const tileposx = id - (tileposy * (tilesetTex.size.x / TILE_W));

    const texpos1 = vec2f(@intToFloat(f32, tileposx) / @intToFloat(f32, tilesetTex.size.x / TILE_W), @intToFloat(f32, tileposy) / @intToFloat(f32, tilesetTex.size.y / TILE_H));
    const texpos2 = vec2f(@intToFloat(f32, tileposx + 1) / @intToFloat(f32, tilesetTex.size.x / TILE_W), @intToFloat(f32, tileposy + 1) / @intToFloat(f32, tilesetTex.size.y / TILE_H));

    fr.drawTextureRect(tilesetTex, texpos1, texpos2, pos.scale(16).intToFloat(f32), vec2f(16, 16)) catch unreachable;
}
