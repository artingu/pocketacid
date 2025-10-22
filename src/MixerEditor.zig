const Mixer = @import("Mixer.zig");
const TextMatrix = @import("TextMatrix.zig");
const RGB = @import("rgb.zig").RGB;
const colors = @import("colors.zig");
const Attrib = @import("CharDisplay.zig").Attrib;
const InputState = @import("ButtonHandler.zig").States;

const Row = enum {
    lvl,
    pan,

    fn next(self: *Row) void {
        self.* = switch (self.*) {
            .lvl => .pan,
            .pan => .lvl,
        };
    }

    fn prev(self: *Row) void {
        self.* = switch (self.*) {
            .lvl => .pan,
            .pan => .lvl,
        };
    }
};

mixer: *Mixer,
selected_channel: u8 = 0,
selected_row: Row = .lvl,

blink: f32 = 0,

pub fn display(self: *@This(), tm: *TextMatrix, x: usize, y: usize, dt: f32) void {
    const on = @mod(self.blink * 4, 1) < 0.5;

    const alter = [_]Attrib{
        colors.hilight,
        colors.normal,
    };

    tm.puts(x, y + 1, colors.normal, "\x0d");
    tm.puts(x, y + 3, colors.normal, "\x12");
    tm.puts(x, y + 4, colors.normal, "\x1d");

    for (&self.mixer.channels, 0..) |*channel, i| {
        const level = @atomicLoad(u8, &channel.level, .seq_cst);
        const pan = @atomicLoad(u8, &channel.pan, .seq_cst);
        const sc = self.selected_channel;
        const sr = self.selected_row;

        const hilight_level = on and sc == i and sr == .lvl;
        const hilight_pan = on and sc == i and sr == .pan;

        const xo = x + 2 + i * 3;
        tm.puts(xo, y + 1, alter[i % 2], channel.label);
        tm.puts(xo, y + 2, alter[i % 2], "\xc4\xc4");
        tm.print(xo, y + 3, invertIf(alter[i % 2], hilight_level), "{x:0>2}", .{level});
        tm.print(xo, y + 4, invertIf(alter[i % 2], hilight_pan), "{x:0>2}", .{pan});
    }

    self.blink = @mod(self.blink + dt, 1);
}

pub fn handle(self: *@This(), input: InputState) void {
    if (input.hold.any()) self.blink = 0;
    const sc = self.selected_channel;
    const sr = self.selected_row;

    if (input.hold.a) {
        const addr = switch (sr) {
            .lvl => &self.mixer.channels[sc].level,
            .pan => &self.mixer.channels[sc].pan,
        };

        const old = @atomicLoad(u8, addr, .seq_cst);
        if (input.repeat.left)
            @atomicStore(u8, addr, old -| 1, .seq_cst)
        else if (input.repeat.right)
            @atomicStore(u8, addr, old +| 1, .seq_cst)
        else if (input.repeat.up)
            @atomicStore(u8, addr, old +| 0x10, .seq_cst)
        else if (input.repeat.down)
            @atomicStore(u8, addr, old -| 0x10, .seq_cst);

        return;
    }

    if (input.combo("right")) self.nextChannel();
    if (input.combo("left")) self.prevChannel();
    if (input.combo("up")) self.selected_row.prev();
    if (input.combo("down")) self.selected_row.next();
}

fn nextChannel(self: *@This()) void {
    self.selected_channel = (self.selected_channel + 1) % @as(u8, @intCast(self.mixer.channels.len));
}

fn prevChannel(self: *@This()) void {
    if (self.selected_channel == 0)
        self.selected_channel = @intCast(self.mixer.channels.len - 1)
    else
        self.selected_channel -= 1;
}

fn invertIf(a: Attrib, condition: bool) Attrib {
    return if (condition)
        a.invert()
    else
        a;
}
