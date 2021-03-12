const math = @import("math");
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;
const Map = @import("./map.zig").Map;
const ecs = @import("ecs");

pub const Position = struct { pos: Vec2i };
pub const Movement = struct { vel: Vec2i };
pub const Render = struct { tid: u16 };
pub const PlayerControl = struct {};
pub const Fighter = struct {
    name: []const u8,
    health: i64,
    healthMax: i64,
    power: i64,
    defense: i64,

    const AttackDescription = struct {
        damage: ?i64,
        otherDead: bool = false,
        otherName: []const u8,
    };

    pub fn attack(this: @This(), map: *Map, otherEntity: ecs.Entity, other: *@This()) AttackDescription {
        const otherName = other.name;

        const damage = this.power - other.defense;
        if (damage <= 0) {
            return .{ .damage = null, .otherName = otherName };
        }

        other.health -= damage;
        var otherDead = other.health <= 0;
        if (otherDead) {
            const position = map.registry.getConst(Position, otherEntity);
            map.registry.destroy(otherEntity);

            var e = map.registry.create();
            map.registry.add(e, Position{ .pos = position.pos });
            map.registry.add(e, Render{ .tid = 720 });
        }

        return .{ .damage = damage, .otherDead = otherDead, .otherName = otherName };
    }
};
