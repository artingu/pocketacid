const DrumPattern = @import("DrumPattern.zig");
const TextMatrix = @import("TextMatrix.zig");
const PlaybackInfo = @import("BassSeq.zig").PlaybackInfo;
const colors = @import("colors.zig");

bank: []DrumPattern,
pattern_idx: u8 = 0,
idx: u8 = 0,

pub fn display(self: *@This(), tm: *TextMatrix, x: usize, y: usize, dt: f32, active: bool, pi: PlaybackInfo) void {
    _ = active;
    _ = pi;
    _ = dt;
    _ = self;

    tm.puts(x + 1, y + 1, colors.playing, "hello, world!");
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
