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

bank: []BassPattern,
pattern_idx: usize = 0,

pub fn handle(self: *@This(), input: InputState) void {
    _ = self;
    _ = input;
}

pub fn display(self: *@This(), tm: *TextMatrix, x: usize, y: usize, dt: f32) void {
    const pattern = self.bank[self.pattern_idx];
    const pattern_len = pattern.length();
    _ = dt;

    for (0..12) |i| {
        tm.puts(x, y + 12 - i, notes[i].attrib, notes[i].str);
    }
    tm.putch(x + 1, y + 14, colors.normal, '+');
    tm.putch(x + 1, y + 15, colors.normal, '-');
    tm.putch(x + 1, y + 16, colors.normal, 4);
    tm.putch(x + 1, y + 17, colors.normal, '/');
    for (0..BassPattern.maxlen) |i| {
        const step = pattern.steps[i].copy();
        self.column(tm, x + 3 + i, y, step, i < pattern_len);
    }
}

fn column(self: *const @This(), tm: *TextMatrix, x: usize, y: usize, step: Step, active: bool) void {
    _ = self;

    // Pitches
    for (0..12) |i| {
        const color: u8 = if (active) colors.normal else colors.inactive;
        const ch: u8 = if (step.pitch == i) 0xdb else '_';
        tm.putch(x, y + 12 - i, color, ch);
    }

    // oct up, down, accent, slide

    tm.putch(x, y + 14, colors.normal, if (step.octup) 0xdb else '.');
    tm.putch(x, y + 15, colors.normal, if (step.octdown) 0xdb else '.');
    tm.putch(x, y + 16, colors.normal, if (step.accent) 0xdb else '.');
    tm.putch(x, y + 17, colors.normal, if (step.slide) 0xdb else '.');
}
