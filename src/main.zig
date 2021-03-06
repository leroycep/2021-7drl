const std = @import("std");
const platform = @import("seizer");
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
const component = @import("./component.zig");

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

var textArena = std.heap.ArenaAllocator.init(allocator);
var adventureLog = std.ArrayList([]const u8).init(allocator);
var map: Map = undefined;
var registry: ecs.Registry = undefined;
var camPos = vec2i(0, 0);

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
        .max_monsters_per_room = 2,
    });

    add_player_to_map(.{
        .name = "player",
        .health = 3,
        .healthMax = 3,
        .power = 2,
        .defense = 1,
    });
    try update_fov();

    try adventureLog.append("You descend into the dungeon, hoping to gain experience and treasure.");
}

fn onDeinit() void {
    std.log.info("app deinit", .{});
    map.deinit();
    adventureLog.deinit();
    textArena.deinit();
    font.deinit();
    flatRenderer.deinit();
    _ = gpa.deinit();
}

pub fn onEvent(event: platform.event.Event) !void {
    var playerMove = vec2i(0, 0);
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

    // Don't change anything if the player didn't move
    if (playerMove.eql(vec2i(0, 0))) return;

    // Move all players entities equal to playerMove
    var changing_levels = false;
    var player_moved = false;
    var player_character_exists = false;
    {
        var view = map.registry.view(.{ component.PlayerControl, component.Position }, .{});
        var iter = view.iterator();
        while (iter.next()) |entity| {
            player_character_exists = true;

            const pos = view.get(component.Position, entity);

            const new_pos = pos.pos.addv(playerMove);
            if (map.getEntityAtPos(new_pos)) |other_entity| {
                // If the entity is a fighter, attack it. Otherwise, ignore it
                if (map.registry.tryGet(component.Fighter, other_entity)) |other_fighter| {
                    const player_fighter = map.registry.getConst(component.Fighter, entity);
                    const attack = player_fighter.attack(&map, other_entity, other_fighter);
                    if (attack.otherDead) {
                        try adventureLog.append(try std.fmt.allocPrint(&textArena.allocator, "You kill the {s}", .{attack.otherName}));
                    } else if (attack.damage) |damage_dealt| {
                        try adventureLog.append(try std.fmt.allocPrint(&textArena.allocator, "You attack the {s}, dealing {} damage", .{ attack.otherName, damage_dealt }));
                    } else {
                        try adventureLog.append(try std.fmt.allocPrint(&textArena.allocator, "You attack the {s}, but deal no damage", .{attack.otherName}));
                    }
                    continue;
                }
            }
            const new_tile_tag = map.get(new_pos);
            if (!new_tile_tag.solid()) {
                player_moved = true;
                pos.pos = new_pos;
                camPos = pos.pos;
                if (new_tile_tag == .StairsDown) {
                    changing_levels = true;
                }
            }
        }
    }

    if (!player_character_exists) return;

    if (changing_levels) {
        var player_fighter: ?component.Fighter = null;
        var view = map.registry.view(.{ component.PlayerControl, component.Fighter }, .{});
        var iter = view.iterator();
        while (iter.next()) |entity| {
            player_fighter = view.getConst(component.Fighter, entity);
        }

        map.deinit();

        // Create map
        map = try generate.generateMap(allocator, .{
            .size = vec2i(50, 50),
            .max_rooms = 50,
            .room_size_range = .{
                .min = 3,
                .max = 10,
            },
            .max_monsters_per_room = 2,
        });

        add_player_to_map(player_fighter.?);
    }

    if (player_moved) {
        try update_fov();
    }
}

fn add_player_to_map(fighter: component.Fighter) void {
    var player = map.registry.create();
    map.registry.add(player, component.Position{ .pos = map.spawn });
    map.registry.add(player, component.Movement{ .vel = vec2i(0, 0) });
    map.registry.add(player, component.Render{ .tid = 25 });
    map.registry.add(player, component.PlayerControl{});
    map.registry.add(player, fighter);
    camPos = map.spawn;
}

fn update_fov() !void {
    map.visible.clearRetainingCapacity();

    var view = map.registry.view(.{ component.Position, component.PlayerControl }, .{});
    var iter = view.iterator();
    while (iter.next()) |entity| {
        const pos = view.getConst(component.Position, entity);
        try map.computeFOV(&map.visible, pos.pos, 8);
    }

    for (map.visible.items()) |entry| {
        try map.explored.put(entry.key, .{});
    }
}

pub fn render(alpha: f64) !void {
    const screen_size = platform.getScreenSize();

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    const cam_size = screen_size.intToFloat(f32);
    const cam_pos = camPos.scale(16).intToFloat(f32).subv(cam_size.scaleDiv(2));

    gl.enable(gl.SCISSOR_TEST);
    gl.scissor(0, 0, screen_size.x, screen_size.y - 50);
    flatRenderer.perspective = Mat4f.orthographic(cam_pos.x, cam_pos.x + cam_size.x, cam_pos.y + cam_size.y, cam_pos.y, -1, 1);
    map.render(&flatRenderer);

    // Render entities
    {
        var view = map.registry.view(.{ component.Position, component.Render }, .{});
        var iter = view.iterator();
        while (iter.next()) |entity| {
            const pos = view.getConst(component.Position, entity);
            if (map.visible.get(pos.pos) == null) continue;
            const r = view.getConst(component.Render, entity);
            render_tile(&flatRenderer, .{ .pos = r.tid }, pos.pos, 1);
        }
    }

    flatRenderer.flush();

    gl.disable(gl.SCISSOR_TEST);
    flatRenderer.perspective = Mat4f.orthographic(0, cam_size.x, cam_size.y, 0, -1, 1);
    var texty: f32 = 50;
    var i = @intCast(isize, adventureLog.items.len) - 1;
    while (i >= 0 and texty > 0) {
        defer {
            i -= 1;
            texty -= 10;
        }
        const text = adventureLog.items[@intCast(usize, i)];
        font.drawText(&flatRenderer, text, vec2f(0, texty), .{});
    }
    flatRenderer.flush();
}

pub fn render_tile(fr: *FlatRenderer, tid: tile.TID, pos: Vec2i, opacity: f32) void {
    const id = tid.pos;

    const tileposy = id / (tilesetTex.size.x / TILE_W);
    const tileposx = id - (tileposy * (tilesetTex.size.x / TILE_W));

    const texpos1 = vec2f(@intToFloat(f32, tileposx) / @intToFloat(f32, tilesetTex.size.x / TILE_W), @intToFloat(f32, tileposy) / @intToFloat(f32, tilesetTex.size.y / TILE_H));
    const texpos2 = vec2f(@intToFloat(f32, tileposx + 1) / @intToFloat(f32, tilesetTex.size.x / TILE_W), @intToFloat(f32, tileposy + 1) / @intToFloat(f32, tilesetTex.size.y / TILE_H));

    fr.drawTextureExt(tilesetTex, pos.scale(16).intToFloat(f32), .{
        .size = vec2f(16, 16),
        .rect = .{
            .min = texpos1,
            .max = texpos2,
        },
        .opacity = opacity,
    });
}
