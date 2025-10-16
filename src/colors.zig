const RGB = @import("rgb.zig").RGB;
const Attrib = @import("CharDisplay.zig").Attrib;

// greenblack
// pub const bg = RGB.init(0, 0, 0);
// pub const inactive = Attrib{ .fg = RGB.init(25, 43, 83), .bg = bg };
// pub const playing = Attrib{ .fg = RGB.init(255, 241, 232), .bg = bg };
// pub const time = Attrib{ .fg = RGB.init(0, 135, 81), .bg = bg };
// pub const normal = Attrib{ .fg = RGB.init(0, 228, 54), .bg = bg };
// pub const hilight = Attrib{ .fg = RGB.init(255, 236, 39), .bg = bg };

pub const bg = RGB.init(48, 48, 48);
pub const inactive = Attrib{ .fg = RGB.init(0, 0, 0), .bg = bg };
pub const playing = Attrib{ .fg = RGB.init(255, 255, 255), .bg = bg };
pub const time = Attrib{ .fg = RGB.init(0, 135, 81), .bg = bg };
pub const normal = Attrib{ .fg = RGB.init(78, 178, 212), .bg = bg };
pub const hilight = Attrib{ .fg = RGB.init(178, 62, 189), .bg = bg };
