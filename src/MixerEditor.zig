const Mixer = @import("Mixer.zig");
const TextMatrix = @import("TextMatrix.zig");
const RGB = @import("rgb.zig").RGB;
const Theme = @import("Theme.zig");
const Attrib = @import("CharDisplay.zig").Attrib;
const InputState = @import("ButtonHandler.zig").States;

const Row = enum {
    lvl,
    pan,
    snd,
    dck,

    fn next(self: *Row) void {
        self.* = switch (self.*) {
            .lvl => .pan,
            .pan => .snd,
            .snd => .dck,
            .dck => .lvl,
        };
    }

    fn prev(self: *Row) void {
        self.* = switch (self.*) {
            .lvl => .dck,
            .pan => .lvl,
            .snd => .pan,
            .dck => .snd,
        };
    }
};

mixer: *Mixer,
channels: *[Mixer.nchannels]Mixer.Channel.Params,
selected_channel: u8 = 0,
selected_row: Row = .lvl,

blink: f32 = 0,

pub fn display(
    self: *@This(),
    tm: *TextMatrix,
    x: usize,
    y: usize,
    dt: f32,
    active: bool,
    colors: *const Theme,
) void {
    const on = @mod(self.blink * 4, 1) < 0.5;

    const alter = [_]Attrib{
        colors.hilight,
        colors.normal,
    };

    const label_color = if (active) colors.normal else colors.hilight2;
    tm.puts(x, y + 1, label_color, "\x0d");
    tm.puts(x, y + 3, label_color, "\x12");
    tm.puts(x, y + 4, label_color, "\x1d");
    tm.puts(x, y + 5, label_color, "\xb0");
    tm.puts(x, y + 6, label_color, "\x11");

    for (self.channels, 0..) |*channel, i| {
        const level = @atomicLoad(u8, &channel.level, .seq_cst);
        const pan = @atomicLoad(u8, &channel.pan, .seq_cst);
        const send = @atomicLoad(u8, &channel.send, .seq_cst);
        const duck = @atomicLoad(u8, &channel.duck, .seq_cst);
        const sc = self.selected_channel;
        const sr = self.selected_row;

        const hilight_level = on and sc == i and sr == .lvl;
        const hilight_pan = on and sc == i and sr == .pan;
        const hilight_snd = on and sc == i and sr == .snd;
        const hilight_dck = on and sc == i and sr == .dck;

        const xo = x + 2 + i * 3;
        tm.puts(xo, y + 1, if (active) alter[i % 2] else colors.hilight2, self.mixer.channels[i].label);
        tm.puts(xo, y + 2, if (active) alter[i % 2] else colors.hilight2, "\xc4\xc4");

        tm.print(xo, y + 3, if (active) invertIf(alter[i % 2], hilight_level) else colors.hilight2, "{x:0>2}", .{level});
        tm.print(xo, y + 4, if (active) invertIf(alter[i % 2], hilight_pan) else colors.hilight2, "{x:0>2}", .{pan});
        tm.print(xo, y + 5, if (active) invertIf(alter[i % 2], hilight_snd) else colors.hilight2, "{x:0>2}", .{send});
        tm.print(xo, y + 6, if (active) invertIf(alter[i % 2], hilight_dck) else colors.hilight2, "{x:0>2}", .{duck});
    }

    self.blink = @mod(self.blink + dt, 1);
}

pub fn handle(self: *@This(), input: InputState, active: bool) void {
    if (!active) return;

    if (input.hold.any()) self.blink = 0;
    const sc = self.selected_channel;
    const sr = self.selected_row;

    if (input.hold.a) {
        const addr = switch (sr) {
            .lvl => &self.channels[sc].level,
            .pan => &self.channels[sc].pan,
            .snd => &self.channels[sc].send,
            .dck => &self.channels[sc].duck,
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
    self.selected_channel = (self.selected_channel + 1) % @as(u8, @intCast(self.channels.len));
}

fn prevChannel(self: *@This()) void {
    if (self.selected_channel == 0)
        self.selected_channel = @intCast(self.channels.len - 1)
    else
        self.selected_channel -= 1;
}

fn invertIf(a: Attrib, condition: bool) Attrib {
    return if (condition)
        a.invert()
    else
        a;
}
