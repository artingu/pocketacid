const Arranger = @This();

const InputState = @import("ButtonHandler.zig").States;
const TextMatrix = @import("TextMatrix.zig");
const colors = @import("colors.zig");

const height = 17;

columns: []const *[256]u8,
column: usize = 0,
row: u8 = 0,
blink: f32 = 0,
changed: bool = false,
yank: u8 = 0,

pub inline fn selectedPattern(self: *const Arranger) ?u8 {
    const over_addr = &self.columns[self.column].*[self.row];
    const curval = @atomicLoad(u8, over_addr, .seq_cst);
    if (curval == 0xff) return null;
    return curval;
}

pub fn handle(self: *Arranger, input: InputState) void {
    const over_addr = &self.columns[self.column].*[self.row];
    const curval = @atomicLoad(u8, over_addr, .seq_cst);
    if (input.hold.any()) self.blink = 0;

    if (input.press.a) {
        if (curval == 0xff) {
            @atomicStore(u8, over_addr, self.yank, .seq_cst);
            self.changed = true;
        } else {
            self.changed = false;
        }
    }

    if (input.release.a) {
        if (!self.changed and curval != 0xff) {
            self.yank = curval;
            @atomicStore(u8, over_addr, 0xff, .seq_cst);
        }
        self.nextRow();
    }

    if (input.combo("b")) {
        @atomicStore(u8, over_addr, 0xff, .seq_cst);
        self.nextRow();
    }

    if (input.combo("a+left") and curval != 0xff) {
        const newval = curval -| 1;
        @atomicStore(u8, over_addr, newval, .seq_cst);
        self.yank = newval;
        self.changed = true;
    }

    if (input.combo("a+right") and curval < 0xfe) {
        const newval = curval + 1;
        @atomicStore(u8, over_addr, newval, .seq_cst);
        self.yank = newval;
        self.changed = true;
    }

    if (input.combo("up")) self.prevRow();
    if (input.combo("down")) self.nextRow();

    if (input.combo("left")) self.prevColumn();
    if (input.combo("right")) self.nextColumn();
}

inline fn nextRow(self: *Arranger) void {
    self.row +%= 1;
}

inline fn prevRow(self: *Arranger) void {
    self.row -%= 1;
}

inline fn nextColumn(self: *Arranger) void {
    self.column = if (self.column == self.columns.len - 1)
        0
    else
        self.column + 1;
}

inline fn prevColumn(self: *Arranger) void {
    self.column = if (self.column == 0)
        self.columns.len - 1
    else
        self.column - 1;
}

pub fn display(self: *Arranger, tm: *TextMatrix, x: usize, y: usize, dt: f32, active: bool) void {
    const half_height: isize = height / 2;
    const on = !active or @mod(self.blink * 4, 1) < 0.5;

    for (0..height) |yoffset| {
        const idx: isize = @as(isize, @intCast(yoffset)) + self.row - half_height;

        if (idx >= 0 and idx < 256) {
            const uidx: u8 = @intCast(idx);
            tm.print(x, y + yoffset, colors.inactive, "{x:0>2}", .{uidx});

            for (self.columns, 1..) |column, xoffset| {
                const alter = [_]u8{ colors.normal, colors.hilight };
                const bc = alter[xoffset % 2];

                const blinked = if (on) invert(bc) else bc;
                const color = if (uidx == self.row and self.column + 1 == xoffset) blinked else bc;

                const val = @atomicLoad(u8, &column.*[uidx], .seq_cst);

                if (val == 0xff)
                    tm.puts(x + xoffset * 2, y + yoffset, color, "..")
                else
                    tm.print(x + xoffset * 2, y + yoffset, color, "{x:0>2}", .{val});
            }
        }
    }

    self.blink = @mod(self.blink + dt, 1);
}

inline fn invert(color: u8) u8 {
    return ((color & 0xf) << 4) | (color >> 4);
}
