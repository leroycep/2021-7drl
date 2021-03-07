const std = @import("std");
const platform = @import("platform");
const gl = platform.gl;
const testing = std.testing;
const FlatRenderer = @import("./flat_render.zig").FlatRenderer;
const zigimg = @import("zigimg");
const vec2f = @import("math").Vec(2, f32).init;

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

var tilesetTex: gl.GLuint = undefined;
var flatRenderer: FlatRenderer = undefined;

pub fn onInit() !void {
    std.log.info("app init", .{});

    var fetch_hello = async platform.fetch(allocator, "hello.txt");
    var fetch_tileset = async platform.fetch(allocator, "colored_tilemap_packed.png");

    const hello_text = try await fetch_hello;
    defer allocator.free(hello_text);

    // == Load tileset
    gl.genTextures(1, &tilesetTex);
    gl.bindTexture(gl.TEXTURE_2D, tilesetTex);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    const tileset_image_contents = try await fetch_tileset;
    defer allocator.free(tileset_image_contents);

    const tileset_image_res = try zigimg.Image.fromMemory(allocator, tileset_image_contents);
    defer tileset_image_res.deinit();
    if (tileset_image_res.pixels == null) return error.ImageLoadFailed;

    // TODO: skip conversion and just tell opengl the format
    var pixelData = try allocator.alloc(u8, tileset_image_res.width * tileset_image_res.height * 4);
    defer allocator.free(pixelData);

    var pixelsIterator = tileset_image_res.iterator();

    var i: usize = 0;
    while (pixelsIterator.next()) |color| : (i += 1) {
        const integer_color = color.toIntegerColor8();
        pixelData[i * 4 + 0] = integer_color.R;
        pixelData[i * 4 + 1] = integer_color.G;
        pixelData[i * 4 + 2] = integer_color.B;
        pixelData[i * 4 + 3] = integer_color.A;
    }

    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(c_int, tileset_image_res.width), @intCast(c_int, tileset_image_res.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, pixelData.ptr);

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

    try flatRenderer.drawGLTexture(tilesetTex, vec2f(0, 0), vec2f(1.0 / (112.0 / TILE_W), 1.0 / (80.0 / TILE_H)), vec2f(0, 0), vec2f(16, 16));
    try flatRenderer.drawGLTexture(tilesetTex, vec2f(1.0 / (112.0 / TILE_W), 0), vec2f(2.0 / (112.0 / TILE_W), 1.0 / (80.0 / TILE_H)), vec2f(16, 0), vec2f(16, 16));
    try flatRenderer.drawGLTexture(tilesetTex, vec2f(2.0 / (112.0 / TILE_W), 0), vec2f(3.0 / (112.0 / TILE_W), 1.0 / (80.0 / TILE_H)), vec2f(32, 0), vec2f(16, 16));
    flatRenderer.flush();
}
