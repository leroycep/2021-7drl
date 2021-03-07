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
pub const os = struct {
    pub const bits = struct {
        pub const fd_t = void;
    };
};

pub fn main() void {
    platform.run(.{
        .init = onInit,
        .deinit = onDeinit,
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
var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false }){};
const allocator = &gpa.allocator;

var tilesetTex: Texture = undefined;
var flatRenderer: FlatRenderer = undefined;

pub fn onInit() !void {
    std.log.info("app init", .{});

    var fetch_hello = async platform.fetch(allocator, "hello.txt");
    var load_tileset = async Texture.initFromFile(allocator, "colored_tilemap_packed.png");

    const hello_text = try await fetch_hello;
    defer allocator.free(hello_text);

    // == Load tileset
    tilesetTex = try await load_tileset;

    // == Initialize renderer
    flatRenderer = try FlatRenderer.init(allocator, platform.getScreenSize().intToFloat(f32));
    std.log.debug("canvas size = {d}", .{platform.getScreenSize().intToFloat(f32)});
}

fn onDeinit() void {
    std.log.info("app deinit", .{});
}

pub fn render(alpha: f64) !void {
    const screen_size_int = platform.getScreenSize();
    const screen_size = screen_size_int.intToFloat(f32);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size_int.x, screen_size_int.y);

    render_tile(0, vec2i(0, 0));
    render_tile(1, vec2i(1, 0));
    render_tile(2, vec2i(2, 0));
    flatRenderer.flush();
}

fn render_tile(id: u16, pos: Vec2i) void {
    const tileposy = id / (TILESET_W / TILE_W);
    const tileposx = id - (tileposy * (TILESET_W / TILE_W));

    const texpos1 = vec2f(@intToFloat(f32, tileposx) / @intToFloat(f32, TILESET_W / TILE_W), @intToFloat(f32, tileposy) / @intToFloat(f32, TILESET_H / TILE_H));
    const texpos2 = vec2f(@intToFloat(f32, tileposx + 1) / @intToFloat(f32, TILESET_W / TILE_W), @intToFloat(f32, tileposy + 1) / @intToFloat(f32, TILESET_H / TILE_H));

    flatRenderer.drawTextureRect(tilesetTex, texpos1, texpos2, pos.scale(16).intToFloat(f32), vec2f(16, 16)) catch unreachable;
}
