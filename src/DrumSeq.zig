const state = @import("state.zig");

const DrumPattern = @import("DrumPattern.zig");
const DrumTrack = @import("DrumTrack.zig");

const TrackSeq = struct {
    idx: usize = 0,
    stepped_last: bool = true,
    trigged_last: bool = false,
    running_last: bool = false,
    track_id: enum { bd, sd, ch, oh, lo, hi, cy },

    fn tick(self: *@This(), running: bool, phase: f32, pattern: *const DrumPattern) ?f32 {
        const tr = self.track(pattern);

        defer self.running_last = running;
        if (running and !self.running_last)
            self.reset();

        if (!running) return null;

        // Step sequencer if necessary
        const step_phase = @mod(phase * @as(f32, @floatFromInt(@atomicLoad(u8, &tr.div, .seq_cst))), 1);
        const stepped = step_phase < 0.5;
        defer self.stepped_last = stepped;
        if (stepped and !self.stepped_last) self.nextStep(pattern);

        // Trigger drums
        const cur = self.currentStep(pattern);
        const trigged = if (cur.gates > 0)
            @mod(step_phase * @as(f32, @floatFromInt(cur.gates)), 1) < 0.5
        else
            false;
        defer self.trigged_last = trigged;
        if (trigged and !self.trigged_last) return (1 + @as(f32, @floatFromInt(cur.velocity))) / 16;

        return null;
    }

    pub fn getIdx(self: *@This()) ?usize {
        return if (self.running_last) @atomicLoad(usize, &self.idx, .seq_cst) else null;
    }

    fn reset(self: *@This()) void {
        self.* = .{ .track_id = self.track_id };
    }

    fn nextStep(self: *@This(), pattern: *const DrumPattern) void {
        const tr = self.track(pattern);
        const len = @atomicLoad(u8, &tr.len, .seq_cst);
        @atomicStore(usize, &self.idx, (self.idx + 1) % len, .seq_cst);
    }

    fn currentStep(self: *@This(), pattern: *const DrumPattern) DrumTrack.Step {
        const tr = self.track(pattern);
        return .{
            .gates = @atomicLoad(u4, &tr.steps[self.idx].gates, .seq_cst),
            .velocity = @atomicLoad(u4, &tr.steps[self.idx].velocity, .seq_cst),
        };
    }

    fn track(self: *const @This(), pattern: *const DrumPattern) *const DrumTrack {
        return switch (self.track_id) {
            .bd => &pattern.bd,
            .sd => &pattern.sd,
            .ch => &pattern.ch,
            .oh => &pattern.oh,
            .lo => &pattern.lo,
            .hi => &pattern.hi,
            .cy => &pattern.cy,
        };
    }
};

pub const Trigs = struct {
    bd: ?f32 = null,
    sd: ?f32 = null,
    ch: ?f32 = null,
    oh: ?f32 = null,
    choh: ?f32 = null,
    lo: ?f32 = null,
    hi: ?f32 = null,
    cy: ?f32 = null,
};

pattern: *DrumPattern = &state.pattern,

bd: TrackSeq = .{ .track_id = .bd },
sd: TrackSeq = .{ .track_id = .sd },
ch: TrackSeq = .{ .track_id = .ch },
oh: TrackSeq = .{ .track_id = .oh },
lo: TrackSeq = .{ .track_id = .lo },
hi: TrackSeq = .{ .track_id = .hi },
cy: TrackSeq = .{ .track_id = .cy },

pub fn tick(self: *@This(), running: bool, phase: f32) Trigs {
    var out = Trigs{};

    if (self.bd.tick(running, phase, self.pattern)) |vel| out.bd = vel;
    if (self.sd.tick(running, phase, self.pattern)) |vel| out.sd = vel;
    if (self.ch.tick(running, phase, self.pattern)) |vel| out.ch = vel;
    if (self.oh.tick(running, phase, self.pattern)) |vel| out.oh = vel;
    if (self.lo.tick(running, phase, self.pattern)) |vel| out.lo = vel;
    if (self.hi.tick(running, phase, self.pattern)) |vel| out.hi = vel;
    if (self.cy.tick(running, phase, self.pattern)) |vel| out.cy = vel;

    // Handle simultaneous ch/oh
    if (out.ch) |ch| {
        if (out.oh) |oh| {
            out.choh = @max(ch, oh);
            out.oh = null;
            out.ch = null;
        }
    }

    return out;
}
