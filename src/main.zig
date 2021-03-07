const std = @import("std");
const platform = @import("platform");
const gl = platform.gl;
const testing = std.testing;
const FlatRenderer = @import("./flat_render.zig").FlatRenderer;
const zigimg = @import("zigimg");
const vec2f = @import("math").Vec(2, f32).init;
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
const TILE_W = 8.0;
const TILE_H = 8.0;

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

    try flatRenderer.drawTextureRect(tilesetTex, vec2f(0, 0), vec2f(1.0 / (112.0 / TILE_W), 1.0 / (80.0 / TILE_H)), vec2f(0, 0), vec2f(16, 16));
    try flatRenderer.drawTextureRect(tilesetTex, vec2f(1.0 / (112.0 / TILE_W), 0), vec2f(2.0 / (112.0 / TILE_W), 1.0 / (80.0 / TILE_H)), vec2f(16, 0), vec2f(16, 16));
    try flatRenderer.drawTextureRect(tilesetTex, vec2f(2.0 / (112.0 / TILE_W), 0), vec2f(3.0 / (112.0 / TILE_W), 1.0 / (80.0 / TILE_H)), vec2f(32, 0), vec2f(16, 16));
    flatRenderer.flush();
}
