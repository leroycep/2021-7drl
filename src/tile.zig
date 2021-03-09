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
    
    ThickWallDownRight,
    ThickWallDownLeft,
    ThickWallUpRight,
    ThickWallUpLeft,
    ThickWallHorizontal,
    ThickWallVertical,
    
    ThickWallDoor0,
};

pub const Desc = struct {
    solid: bool,
    texture: ?u16,
};

pub const DESCRIPTIONS = comptime gen_descs: {
    var max_id = 0;
    for (@typeInfo(Tag).Enum.fields) |field| {
        if (field.value > max_id) {
            max_id = field.value + 1;
        }
    }

    var desc: [max_id]Desc = undefined;

    desc[@enumToInt(Tag.Empty)] = .{
        .solid = false,
        .texture = 15,
    };

    desc[@enumToInt(Tag.WallDownRight)] = .{
        .solid = true,
        .texture = 0,
    };
    
    desc[@enumToInt(Tag.WallDownLeft)] = .{
        .solid = true,
        .texture = 3,
    };
    
    desc[@enumToInt(Tag.WallUpRight)] = .{
        .solid = true,
        .texture = 28,
    };
    
    desc[@enumToInt(Tag.WallUpLeft)] = .{
        .solid = true,
        .texture = 31,
    };
    
    desc[@enumToInt(Tag.WallHorizontal)] = .{
        .solid = true,
        .texture = 1,
    };
    
    desc[@enumToInt(Tag.WallVerticalLeft)] = .{
        .solid = true,
        .texture = 14,
    };
    
    desc[@enumToInt(Tag.WallVerticalRight)] = .{
        .solid = true,
        .texture = 17,
    };
    
    desc[@enumToInt(Tag.WallDownRightSquare)] = .{
        .solid = true,
        .texture = 56,
    };
    
    desc[@enumToInt(Tag.WallDownLeftSquare)] = .{
        .solid = true,
        .texture = 57,
    };
    
    desc[@enumToInt(Tag.WallDownRightT)] = .{
        .solid = true,
        .texture = 70,
    };
    
    desc[@enumToInt(Tag.WallDownLeftT)] = .{
        .solid = true,
        .texture = 71,
    };
    
    desc[@enumToInt(Tag.WallDoor0)] = .{
        .solid = false,
        .texture = 2,
    };

    // Thick Wall
    desc[@enumToInt(Tag.ThickWallDownRight)] = .{
        .solid = true,
        .texture = 126,
    };
    
    desc[@enumToInt(Tag.ThickWallDownLeft)] = .{
        .solid = true,
        .texture = 129,
    };
    
    desc[@enumToInt(Tag.ThickWallUpRight)] = .{
        .solid = true,
        .texture = 132,
    };
    
    desc[@enumToInt(Tag.ThickWallUpLeft)] = .{
        .solid = true,
        .texture = 135,
    };
    
    desc[@enumToInt(Tag.ThickWallHorizontal)] = .{
        .solid = true,
        .texture = 127,
    };
    
    desc[@enumToInt(Tag.ThickWallVertical)] = .{
        .solid = true,
        .texture = 130,
    };
    
    desc[@enumToInt(Tag.ThickWallDoor0)] = .{
        .solid = true,
        .texture = 128,
    };
    
    break :gen_descs desc;
};
