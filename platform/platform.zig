const std = @import("std");
const Timer = std.time.Timer;

pub const event = @import("./event.zig");
pub const backend = if (std.builtin.arch == .wasm32) @import("web/web.zig") else @import("sdl/sdl.zig");

pub usingnamespace backend;

pub const App = struct {
    init: fn () callconv(.Async) anyerror!void = onInitDoNothing,
    deinit: fn () void = onDeinitDoNothing,
    event: fn (event: event.Event) anyerror!void = onEventDoNothing,
    update: fn (currentTime: f64, delta: f64) anyerror!void = onUpdateDoNothing,
    render: fn (alpha: f64) anyerror!void,
    window: struct {
        title: [:0]const u8 = "Zig Game Engine",
        width: ?i32 = null,
        height: ?i32 = null,
    } = .{},
    maxDeltaSeconds: f64 = 0.25,
    tickDeltaSeconds: f64 = 16.0 / 1000.0,
};

fn onInitDoNothing() anyerror!void {}
fn onDeinitDoNothing() void {}
fn onEventDoNothing(_e: event.Event) anyerror!void {}
fn onUpdateDoNothing(currentTime: f64, delta: f64) anyerror!void {}
