const RGB = @import("rgb.zig").RGB;
const Attrib = @import("CharDisplay.zig").Attrib;
const NextPrevEnum = @import("NextPrevEnum.zig").NextPrevEnum;
const Theme = @This();

normal: Attrib,
hilight: Attrib,
hilight2: Attrib,
playing: Attrib,

pub const Id = enum {
    term,
    panel,
    forest,
    papaya,

    pub fn resolve(self: Id) *const Theme {
        return switch (self) {
            .term => &term,
            .panel => &panel,
            .forest => &forest,
            .papaya => &papaya,
        };
    }

    pub usingnamespace NextPrevEnum(Id);
};

const term = theme(.{
    .bg = RGB.init(0, 0, 0),
    .hilight2 = RGB.init(80, 43, 255),
    .playing = RGB.init(255, 241, 232),
    .normal = RGB.init(0, 228, 54),
    .hilight = RGB.init(255, 236, 39),
});

const panel = theme(.{
    .bg = RGB.init(48, 48, 48),
    .hilight2 = RGB.init(0, 0, 0),
    .playing = RGB.init(255, 255, 255),
    .normal = RGB.init(78, 178, 212),
    .hilight = RGB.init(178, 62, 189),
});

const forest = theme(.{
    .bg = RGB.init(30, 48, 28),
    .hilight2 = RGB.init(97, 161, 87),
    .playing = RGB.init(255, 255, 255),
    .normal = RGB.init(161, 148, 87),
    .hilight = RGB.init(161, 109, 87),
});

const papaya = theme(.{
    .bg = RGB.init(0xff, 0xee, 0xcc),
    .hilight2 = RGB.init(0x44, 0x66, 0x22),
    .normal = RGB.init(0x22, 0x44, 0x66),
    .playing = RGB.init(192, 192, 0),
    .hilight = RGB.init(0x66, 0x22, 0x44),
});

fn theme(th: InnerTheme) Theme {
    return .{
        .normal = Attrib{ .fg = th.normal, .bg = th.bg },
        .hilight = Attrib{ .fg = th.hilight, .bg = th.bg },
        .hilight2 = Attrib{ .fg = th.hilight2, .bg = th.bg },
        .playing = Attrib{ .fg = th.playing, .bg = th.bg },
    };
}

const InnerTheme = struct {
    bg: RGB,
    normal: RGB,
    hilight: RGB,
    hilight2: RGB,
    playing: RGB,
};
