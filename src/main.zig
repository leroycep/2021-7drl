const std = @import("std");
const platform = @import("platform");
const gl = platform.gl;
const testing = std.testing;

pub const panic = platform.panic;
pub const log = platform.log;

var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false }){};
const allocator = &gpa.allocator;

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

pub fn onInit() !void {
    std.log.info("app init", .{});
    
    var fetch_hello = async platform.fetch(allocator, "hello.txt");
    
    const hello_text = try await fetch_hello;
    defer allocator.free(hello_text);
    
    std.log.info("Hello text = {s}", .{hello_text});
}

fn onDeinit() void {
    std.log.info("app deinit", .{});
}

pub fn render(alpha: f64) !void {
    const screen_size_int = platform.getScreenSize();
    const screen_size = screen_size_int.intToFloat(f32);

    gl.clearColor(0.5, 0.5, 0.5, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size_int.x, screen_size_int.y);
}
