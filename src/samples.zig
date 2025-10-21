pub const bd = @embedFile("assets/samples/bd.raw");
pub const ch = @embedFile("assets/samples/ch.raw");
pub const oh = @embedFile("assets/samples/oh.raw");
pub const cy = @embedFile("assets/samples/cy.raw");
pub const hi = @embedFile("assets/samples/hi.raw");
pub const lo = @embedFile("assets/samples/lo.raw");
pub const sd = @embedFile("assets/samples/sd.raw");
pub const choh = @embedFile("assets/samples/choh.raw");

pub const Player = struct {
    index: usize = 0,
    sample: []const u8 = &.{},
    rate: f32 = 32000,
    phase: f32 = 0,
    volume: f32 = 1.0,

    pub fn next(self: *Player, srate: f32) f32 {
        if (self.index >= self.sample.len) {
            return 0;
        }
        while (self.phase >= 1) {
            self.phase -= 1;
            self.index += 2;
        }
        self.phase += self.rate / srate;
        if (self.index < self.sample.len) {
            const intsample: i16 = @as(i16, @intCast(self.sample[self.index])) | (@as(i16, @intCast(self.sample[self.index + 1])) << 8);
            const floatsample: f32 = @as(f32, @floatFromInt(intsample)) / 32768;

            return self.volume * floatsample;
        }
        return 0;
    }

    pub fn stop(self: *Player) void {
        self.index = self.sample.len;
    }

    pub fn trigger(self: *Player, sample: []const u8, volume: f32) void {
        self.volume = volume * volume;
        self.sample = sample;
        self.index = 0;
        self.phase = 0;
    }
};
