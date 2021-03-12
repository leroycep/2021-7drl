const math = @import("math");
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;

pub const Position = struct { pos: Vec2i };
pub const Movement = struct { vel: Vec2i };
pub const Render = struct { tid: u16 };
pub const PlayerControl = struct {};
pub const Creature = struct {
    health: i64,
    healthMax: i64,
};
