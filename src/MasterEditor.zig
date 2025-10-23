const colors = @import("colors.zig");

const TextMatrix = @import("TextMatrix.zig");
const InputState = @import("ButtonHandler.zig").States;
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const Attrib = @import("CharDisplay.zig").Attrib;

pub const Entry = struct {
    label: []const u8,
    ptr: *u8,

    fn inc(self: *const Entry, by: u8) void {
        const prev = @atomicLoad(u8, self.ptr, .seq_cst);
        @atomicStore(u8, self.ptr, prev +| by, .seq_cst);
    }

    fn dec(self: *const Entry, by: u8) void {
        const prev = @atomicLoad(u8, self.ptr, .seq_cst);
        @atomicStore(u8, self.ptr, prev -| by, .seq_cst);
    }
};

menu: []const Entry,

idx: u8 = 0,
blink: f32 = 0,

pub fn display(self: *@This(), tm: *TextMatrix, x: usize, y: usize, dt: f32, active: bool) void {
    const on = @mod(self.blink * 4, 1) < 0.5;
    for (self.menu, 0..) |entry, i| {
        const value = @atomicLoad(u8, entry.ptr, .seq_cst);
        const color = if (!active)
            colors.inactive
        else if (i == self.idx)
            invertIf(colors.hilight, on)
        else
            colors.normal;

        tm.print(x, y + i, color, "{s} {x:0>2}", .{ entry.label, value });
    }
    self.blink = @mod(self.blink + dt, 1);
}

pub fn handle(self: *@This(), input: InputState, active: bool) void {
    if (!active) return;
    if (input.hold.any()) self.blink = 0;

    const entry = self.menu[self.idx];
    if (input.hold.a) {
        if (input.repeat.up) entry.inc(16);
        if (input.repeat.down) entry.dec(16);
        if (input.repeat.left) entry.dec(1);
        if (input.repeat.right) entry.inc(1);
        return;
    }

    if (input.repeat.up) self.idx -|= 1;
    if (input.repeat.down) self.idx = @min(self.menu.len - 1, self.idx + 1);
}

fn invertIf(a: Attrib, condition: bool) Attrib {
    return if (condition)
        a.invert()
    else
        a;
}
