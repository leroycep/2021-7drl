const Map = @import("./map.zig").Map;
const math = @import("math");
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;

pub const Tag = enum(u16) {
    Empty,
    Floor,
    Wall,
};

pub const Desc = struct {
    solid: bool,
    render: RenderInfo,
};

pub const RenderInfo = union(enum) {
    None: void,
    Static: TID,
    // Connects with similar blocks
    Connected: [11]TID,
};

pub const TID = struct {
    pos: u16,
    rot: u2 = 0,
};

pub const Neighbors = packed struct {
    n: bool,
    e: bool,
    s: bool,
    w: bool,

    pub fn toConnection(this: @This()) Connection {
        return @intToEnum(Connection, @bitCast(u4, this));
    }
};

pub const Connection = enum(u4) {
    None = 0b0000,
    North = 0b0001,
    East = 0b0010,
    South = 0b0100,
    West = 0b1000,

    NorthSouth = 0b0101,

    NorthEast = 0b0011,
    NorthWest = 0b1001,
    SouthEast = 0b0110,
    SouthWest = 0b1100,

    EastWest = 0b1010,

    NorthSouthEast = 0b0111,
    NorthEastWest = 0b1011,
    NorthSouthWest = 0b1101,
    SouthEastWest = 0b1110,

    NorthSouthEastWest = 0b1111,

    pub fn toNeighbors(this: @This()) Neighbors {
        return @bitCast(Neighbors, @enumToInt(this));
    }
};

pub const DESCRIPTIONS = comptime gen_descs: {
    var max_id = 0;
    for (@typeInfo(Tag).Enum.fields) |field| {
        if (field.value > max_id) {
            max_id = field.value;
        }
    }

    var desc: [max_id + 1]Desc = undefined;

    desc[@enumToInt(Tag.Empty)] = .{
        .solid = false,
        .render = .None,
    };

    desc[@enumToInt(Tag.Floor)] = .{
        .solid = false,
        .render = .{ .Static = .{ .pos = 0 } },
    };

    // Thick Wall
    desc[@enumToInt(Tag.Wall)] = .{
        .solid = true,
        .render = .{ .Static = .{ .pos = 826 } },
    };

    break :gen_descs desc;
};
