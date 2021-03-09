const Map = @import("./map.zig").Map;
const math = @import("math");
const Vec2i = math.Vec(2, i64);
const vec2i = Vec2i.init;

pub const Tag = enum(u16) {
    Empty,

    WallDownRight,
    WallDownLeft,
    WallUpRight,
    WallUpLeft,
    WallHorizontal,
    WallVerticalLeft,
    WallVerticalRight,
    WallDownRightSquare,
    WallDownLeftSquare,
    WallDownRightT,
    WallDownLeftT,

    WallDoor0,

    ThickWall,

    ThickWallDoor0,
};

pub const Desc = struct {
    solid: bool,
    render: RenderInfo,
};

pub const RenderInfo = union(enum) {
    Static: u16,
    // Connects with similar blocks
    Connected: [11]u16,
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
        .render = .{ .Static = 15 },
    };

    desc[@enumToInt(Tag.WallDownRight)] = .{
        .solid = true,
        .render = .{ .Static = 0 },
    };

    desc[@enumToInt(Tag.WallDownLeft)] = .{
        .solid = true,
        .render = .{ .Static = 3 },
    };

    desc[@enumToInt(Tag.WallUpRight)] = .{
        .solid = true,
        .render = .{ .Static = 28 },
    };

    desc[@enumToInt(Tag.WallUpLeft)] = .{
        .solid = true,
        .render = .{ .Static = 31 },
    };

    desc[@enumToInt(Tag.WallHorizontal)] = .{
        .solid = true,
        .render = .{ .Static = 1 },
    };

    desc[@enumToInt(Tag.WallVerticalLeft)] = .{
        .solid = true,
        .render = .{ .Static = 14 },
    };

    desc[@enumToInt(Tag.WallVerticalRight)] = .{
        .solid = true,
        .render = .{ .Static = 17 },
    };

    desc[@enumToInt(Tag.WallDownRightSquare)] = .{
        .solid = true,
        .render = .{ .Static = 56 },
    };

    desc[@enumToInt(Tag.WallDownLeftSquare)] = .{
        .solid = true,
        .render = .{ .Static = 57 },
    };

    desc[@enumToInt(Tag.WallDownRightT)] = .{
        .solid = true,
        .render = .{ .Static = 70 },
    };

    desc[@enumToInt(Tag.WallDownLeftT)] = .{
        .solid = true,
        .render = .{ .Static = 71 },
    };

    desc[@enumToInt(Tag.WallDoor0)] = .{
        .solid = false,
        .render = .{ .Static = 2 },
    };

    // Thick Wall
    desc[@enumToInt(Tag.ThickWall)] = .{
        .solid = true,
        .render = .{
            .Connected = .{
                127,
                130,
                127,
                130,
                127,

                130,

                132,
                135,
                126,
                129,

                127,
            },
        },
    };

    desc[@enumToInt(Tag.ThickWallDoor0)] = .{
        .solid = true,
        .render = .{ .Static = 128 },
    };

    break :gen_descs desc;
};
