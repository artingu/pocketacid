// Copyright (C) 2025  Philip Linde
//
// This file is part of Pocket Acid.
//
// Pocket Acid is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Pocket Acid is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Pocket Acid.  If not, see <https://www.gnu.org/licenses/>.

const RGB = @import("rgb.zig").RGB;
const sdl = @import("sdl.zig");

w: usize,
h: usize,
fonttype: *FontType,
lastfonttype: FontType = .mcr,

cells: []Cell,
last_rendered: []Cell,
out: *sdl.Renderer,
font: *sdl.Texture,

pub const FontType = enum {
    normal,
    thin,
    mcr,
    fantasy,

    fn offset(self: FontType) sdl.Point {
        return switch (self) {
            .normal => .{ .x = 128, .y = 0 },
            .thin => .{ .x = 128, .y = 128 },
            .mcr => .{ .x = 0, .y = 0 },
            .fantasy => .{ .x = 0, .y = 128 },
        };
    }
};

pub const Attrib = packed struct {
    fg: RGB = RGB.init(0, 0, 0),
    bg: RGB = RGB.init(0, 0, 0),

    pub inline fn invert(self: Attrib) Attrib {
        return .{ .fg = self.bg, .bg = self.fg };
    }
};

pub const Cell = packed struct {
    attrib: Attrib,
    char: u8,

    fn eq(self: Cell, other: Cell) bool {
        return self.char == other.char and self.attrib == other.attrib;
    }
};

pub fn flush(self: *@This(), force: bool) void {
    const force_flush = force or (self.lastfonttype != self.fonttype.*);
    for (0..self.h) |y| for (0..self.w) |x| {
        const idx = x + y * self.w;
        if (!self.cells[idx].eq(self.last_rendered[idx]) or force_flush)
            self.renderCell(x, y);
    };
    self.lastfonttype = self.fonttype.*;
}

inline fn renderCell(self: *const @This(), x: usize, y: usize) void {
    const o = self.fonttype.offset();
    const bgsrc = sdl.Rect{ .x = 0xb * 8 + o.x, .y = 0xd * 8 + o.y, .w = 8, .h = 8 };
    const cell = self.cells[x + y * self.w];
    const src_x: c_int = @intCast(cell.char & 0xf);
    const src_y: c_int = @intCast(cell.char >> 4);
    const src = sdl.Rect{ .x = src_x * 8 + o.x, .y = src_y * 8 + o.y, .w = 8, .h = 8 };
    const dst = sdl.Rect{ .x = @intCast(x * 8), .y = @intCast(y * 8), .w = 8, .h = 8 };

    const fg = cell.attrib.fg;
    const bg = cell.attrib.bg;

    // Render bg
    _ = sdl.setTextureColorMod(self.font, bg.r, bg.g, bg.b);
    _ = sdl.renderCopy(self.out, self.font, &bgsrc, &dst);

    // Render fg
    _ = sdl.setTextureColorMod(self.font, fg.r, fg.g, fg.b);
    _ = sdl.renderCopy(self.out, self.font, &src, &dst);

    // Update last_rendered
    self.last_rendered[x + y * self.w] = cell;
}
