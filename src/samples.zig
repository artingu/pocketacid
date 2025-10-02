pub const bd = &embedSample("assets/samples/bd.raw").s;
pub const ch = &embedSample("assets/samples/ch.raw").s;
pub const oh = &embedSample("assets/samples/oh.raw").s;
pub const cy = &embedSample("assets/samples/cy.raw").s;
pub const hi = &embedSample("assets/samples/hi.raw").s;
pub const lo = &embedSample("assets/samples/lo.raw").s;
pub const sd = &embedSample("assets/samples/sd.raw").s;

pub const choh = &embedSample("assets/samples/choh.raw").s;

pub const Player = struct {
    index: usize = 0,
    sample: []const f32 = undefined,
    rate: f32 = 32000,
    phase: f32 = 0,
    volume: f32 = 1.0,

    pub fn next(self: *Player, srate: f32) f32 {
        if (self.index >= self.sample.len) {
            return 0;
        }
        while (self.phase >= 1) {
            self.phase -= 1;
            self.index += 1;
        }
        self.phase += self.rate / srate;
        if (self.index < self.sample.len) {
            return self.volume * self.sample[self.index];
        }
        return 0;
    }

    pub fn stop(self: *Player) void {
        self.index = self.sample.len;
    }

    pub fn trigger(self: *Player, sample: []const f32, volume: f32) void {
        self.volume = volume * volume * volume;
        self.sample = sample;
        self.index = 0;
        self.phase = 0;
    }
};

fn embedSample(comptime path: []const u8) type {
    @setEvalBranchQuota(100000);
    const data = @embedFile(path);
    comptime var converted: [@divTrunc(data.len, 2)]f32 = undefined;
    for (0..converted.len) |i| {
        converted[i] = @as(f32, @floatFromInt(@as(i16, @bitCast(@as(u16, @intCast(data[i << 1])) | (@as(u16, @intCast(data[(i << 1) + 1])) << 8))))) / 32768;
    }
    return struct {
        const s = converted;
    };
}
