const BassPattern = @import("BassPattern.zig");
const Step = BassPattern.Step;
const InputState = @import("ButtonHandler.zig").States;
const TextMatrix = @import("TextMatrix.zig");
const colors = @import("colors.zig");

const NoteInfo = struct {
    str: []const u8,
    attrib: u8,
};

const wh = 0x0b;
const bl = 0xb0;

const notes = [12]NoteInfo{
    .{ .str = "C ", .attrib = wh },
    .{ .str = "C#", .attrib = bl },
    .{ .str = "D ", .attrib = wh },
    .{ .str = "D#", .attrib = bl },
    .{ .str = "E ", .attrib = wh },
    .{ .str = "F ", .attrib = wh },
    .{ .str = "F#", .attrib = bl },
    .{ .str = "G ", .attrib = wh },
    .{ .str = "G#", .attrib = bl },
    .{ .str = "A ", .attrib = wh },
    .{ .str = "A#", .attrib = bl },
    .{ .str = "B ", .attrib = wh },
};

const Row = union(enum) {
    note: u4,
    attrib: enum { up, down, accent, slide },
};

bank: []BassPattern,
pattern_idx: usize = 0,
idx: usize = 0,
row: usize = 0,
blink: f32 = 0,
buffer: BassPattern.Step = .{ .pitch = 0 },

pub fn handle(self: *@This(), input: InputState) void {
    const step = self.selectedStep();

    if (input.hold.any()) self.blink = 0;

    if (input.press.b and step.active()) {
        self.buffer = step.copy();
        step.delete();
    }

    if (input.combo("right")) self.nextIdx();
    if (input.combo("left")) self.prevIdx();
}

fn selectedStep(self: *const @This()) *BassPattern.Step {
    return &self.selectedTrack().steps[self.idx];
}

fn selectedTrack(self: *const @This()) *BassPattern {
    return &self.bank[self.pattern_idx];
}

fn nextIdx(self: *@This()) void {
    self.idx = (self.idx + 1) % self.selectedTrack().len;
}

fn prevIdx(self: *@This()) void {
    self.idx = if (self.idx != 0)
        (self.idx - 1) % self.selectedTrack().len
    else
        self.selectedTrack().len - 1;
}

pub fn display(self: *@This(), tm: *TextMatrix, x: usize, y: usize, dt: f32) void {
    const pattern = self.bank[self.pattern_idx];
    const pattern_len = pattern.length();
    const on = @mod(self.blink * 4, 1) < 0.5;

    for (0..12) |i| {
        tm.puts(x, y + 12 - i, notes[i].attrib, notes[i].str);
    }
    tm.putch(x + 1, y + 14, colors.normal, '+');
    tm.putch(x + 1, y + 15, colors.normal, '-');
    tm.putch(x + 1, y + 16, colors.normal, 4);
    tm.putch(x + 1, y + 17, colors.normal, '/');
    for (0..BassPattern.maxlen) |i| {
        self.column(tm, x + 3 + i, y, i, i < pattern_len, on);
    }

    self.blink = @mod(self.blink + dt, 1);
}

inline fn invert(color: u8) u8 {
    return ((color & 0xf) << 4) | (color >> 4);
}

fn column(self: *const @This(), tm: *TextMatrix, x: usize, y: usize, idx: usize, active: bool, blink: bool) void {
    const pattern = self.bank[self.pattern_idx];
    const step = pattern.steps[idx].copy();
    const color: u8 = if (active) colors.normal else colors.inactive;
    const blinked = if (blink and idx == self.idx) invert(color) else color;

    // Pitches
    for (0..12) |i| {
        const ch: u8 = if (step.pitch == i) 0xdb else '_';
        tm.putch(x, y + 12 - i, blinked, ch);
    }

    // oct up, down, accent, slide

    tm.putch(x, y + 14, colors.normal, if (step.octup) 0xdb else '.');
    tm.putch(x, y + 15, colors.normal, if (step.octdown) 0xdb else '.');
    tm.putch(x, y + 16, colors.normal, if (step.accent) 0xdb else '.');
    tm.putch(x, y + 17, colors.normal, if (step.slide) 0xdb else '.');
}
