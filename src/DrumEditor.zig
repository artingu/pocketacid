const InputState = @import("ButtonHandler.zig").States;
const DrumPattern = @import("DrumPattern.zig");
const DrumMachine = @import("DrumMachine.zig");
const TextMatrix = @import("TextMatrix.zig");
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const colors = @import("colors.zig");

bank: []DrumPattern,
pattern_idx: u8 = 0,
idx: u8 = 0,
blink: f32 = 0,
drumtype: DrumPattern.DrumType = .bd,

pub fn handle(self: *@This(), input: InputState) void {
    if (input.hold.any()) self.blink = 0;

    if (input.hold.y) {
        if (input.repeat.left) self.selectedPattern().decLength();
        if (input.repeat.right) self.selectedPattern().incLength();
        return;
    }

    if (input.repeat.up) self.drumtype.prev();
    if (input.repeat.down) self.drumtype.next();
    if (input.repeat.left) self.prevIdx();
    if (input.repeat.right) self.nextIdx();
    if (input.repeat.a) {
        self.selectedStep().toggle(self.drumtype);
        self.nextIdx();
    }
    if (input.repeat.b) {
        self.selectedStep().set(self.drumtype, false);
        self.nextIdx();
    }
}

pub fn display(
    self: *@This(),
    tm: *TextMatrix,
    xo: usize,
    yo: usize,
    dt: f32,
    active: bool,
    pi: PlaybackInfo,
    mutes: DrumMachine.Mutes,
) void {
    const current_pattern = self.selectedPattern();
    const current_len = current_pattern.length();
    const on = active and @mod(self.blink * 4, 1) < 0.5;

    tm.print(xo + 3, yo, colors.inactive, "ptn:{x:0>2}", .{self.pattern_idx});

    inline for (DrumPattern.types, 0..) |t, i| {
        tm.puts(xo, yo + 1 + i, if (t.muted(mutes)) colors.hilight else colors.normal, t.str());
    }

    for (DrumPattern.types, 0..) |t, row| {
        for (0..DrumPattern.maxlen) |column| {
            const x = xo + 3 + column;
            const y = yo + 1 + row;

            const playing = pi.pattern == self.pattern_idx and pi.step == column and pi.running;

            const base_color = if (playing)
                colors.playing
            else if (column >= current_len)
                colors.inactive
            else if (column % 4 == 0)
                colors.hilight
            else
                colors.normal;

            const do_marker = on and t == self.drumtype and column == self.idx and on;
            const color = if (do_marker)
                base_color.invert()
            else
                base_color;

            const step = &current_pattern.steps[column];
            if (step.get(t))
                tm.puts(x, y, color, "\x09")
            else
                tm.puts(x, y, color, ".");
        }
    }

    self.blink = @mod(self.blink + dt, 1);
}

fn selectedStep(self: *const @This()) *DrumPattern.Step {
    return &self.selectedPattern().steps[self.idx];
}

fn selectedPattern(self: *const @This()) *DrumPattern {
    return &self.bank[self.pattern_idx];
}

pub inline fn setPattern(self: *@This(), pat: u8) void {
    self.pattern_idx = pat;
    self.idx = @min(self.idx, self.selectedPattern().length() - 1);
}

inline fn nextIdx(self: *@This()) void {
    self.idx = (self.idx + 1) % self.selectedPattern().len;
}

inline fn prevIdx(self: *@This()) void {
    self.idx = if (self.idx != 0)
        (self.idx - 1) % self.selectedPattern().len
    else
        self.selectedPattern().len - 1;
}
