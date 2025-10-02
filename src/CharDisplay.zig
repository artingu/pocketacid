const RGB = @import("RGB.zig");
const sdl = @import("sdl.zig");

palette: [16]RGB,
w: usize,
h: usize,
cells: []Cell,
last_rendered: []Cell,
out: *sdl.Renderer,
font: *sdl.Texture,

pub const Cell = packed struct {
    char: u8,
    attrib: u8,

    fn eq(self: Cell, other: Cell) bool {
        return self.char == other.char and self.attrib == other.attrib;
    }
};

pub fn flush(self: *const @This()) void {
    for (0..self.h) |y| for (0..self.w) |x| {
        const idx = x + y * self.w;
        if (!self.cells[idx].eq(self.last_rendered[idx]))
            self.renderCell(x, y);
    };
}

inline fn renderCell(self: *const @This(), x: usize, y: usize) void {
    const bgsrc = sdl.Rect{ .x = 0xb * 8, .y = 0xd * 8, .w = 8, .h = 8 };
    const cell = self.cells[x + y * self.w];
    const src_x: c_int = @intCast(cell.char & 0xf);
    const src_y: c_int = @intCast(cell.char >> 4);
    const src = sdl.Rect{ .x = src_x * 8, .y = src_y * 8, .w = 8, .h = 8 };
    const dst = sdl.Rect{ .x = @intCast(x * 8), .y = @intCast(y * 8), .w = 8, .h = 8 };

    const fgc = cell.attrib >> 4;
    const bgc = cell.attrib & 0xf;
    const fg = self.palette[@as(usize, @intCast(fgc))];
    const bg = self.palette[@as(usize, @intCast(bgc))];

    // Render bg
    _ = sdl.setTextureColorMod(self.font, bg.r, bg.g, bg.b);
    _ = sdl.renderCopy(self.out, self.font, &bgsrc, &dst);

    // Render fg
    _ = sdl.setTextureColorMod(self.font, fg.r, fg.g, fg.b);
    _ = sdl.renderCopy(self.out, self.font, &src, &dst);

    // Update last_rendered
    self.last_rendered[x + y * self.w] = cell;
}
