const samples = @import("samples.zig");

const DrumSeq = @import("DrumSeq.zig");

const maxtempo = 9999;
const mintempo = 1;

pub const Trigger = enum {
    bd,
    sd,
    ch,
    oh,
    lo,
    hi,
    cy,
};

players: struct {
    bd: samples.Player = .{},
    sd: samples.Player = .{},
    hh: samples.Player = .{},
    cy: samples.Player = .{},
    hi: samples.Player = .{},
    lo: samples.Player = .{},
} = .{},

triggers: u8 = 0,
phase: f32 = 0,
bpm: f32 = 120,

running: bool = false,
toggle_running: bool = false,
ds: DrumSeq = .{},

pub fn everyBuffer(self: *@This()) void {
    const bits = @atomicRmw(u8, &self.triggers, .And, 0, .seq_cst);
    const chtrig = bits & 4 != 0;
    const ohtrig = bits & 8 != 0;

    if (chtrig and ohtrig)
        self.players.hh.trigger(samples.choh, 1)
    else if (chtrig)
        self.players.hh.trigger(samples.ch, 1)
    else if (ohtrig)
        self.players.hh.trigger(samples.oh, 1);
    if (bits & 1 != 0) self.players.bd.trigger(samples.bd, 1);
    if (bits & 2 != 0) self.players.sd.trigger(samples.sd, 1);
    if (bits & 16 != 0) self.players.cy.trigger(samples.cy, 1);
    if (bits & 32 != 0) self.players.lo.trigger(samples.lo, 1);
    if (bits & 64 != 0) self.players.hi.trigger(samples.hi, 1);

    if (@atomicRmw(bool, &self.toggle_running, .Xchg, false, .seq_cst)) {
        if (self.running) {
            @atomicStore(bool, &self.running, false, .seq_cst);
            self.phase = 0;
        } else {
            @atomicStore(bool, &self.running, true, .seq_cst);
        }
    }
}

pub fn trigger(self: *@This(), t: Trigger) void {
    const orval: u8 = switch (t) {
        .bd => 1,
        .sd => 2,
        .ch => 4,
        .oh => 8,
        .cy => 16,
        .lo => 32,
        .hi => 64,
    };

    _ = @atomicRmw(u8, &self.triggers, .Or, orval, .seq_cst);
}

pub fn next(self: *@This(), srate: f32) f32 {
    var out: f32 = 0;

    const trigs = self.ds.tick(self.running, self.phase);

    if (trigs.bd) |vel| self.players.bd.trigger(samples.bd, vel);
    if (trigs.sd) |vel| self.players.sd.trigger(samples.sd, vel);
    if (trigs.ch) |vel| self.players.hh.trigger(samples.ch, vel);
    if (trigs.oh) |vel| self.players.hh.trigger(samples.oh, vel);
    if (trigs.choh) |vel| self.players.hh.trigger(samples.choh, vel);
    if (trigs.lo) |vel| self.players.lo.trigger(samples.lo, vel);
    if (trigs.hi) |vel| self.players.hi.trigger(samples.hi, vel);
    if (trigs.cy) |vel| self.players.cy.trigger(samples.cy, vel);

    out += self.players.bd.next(srate);
    out += self.players.sd.next(srate);
    out += self.players.hh.next(srate);
    out += self.players.cy.next(srate);
    out += self.players.lo.next(srate);
    out += self.players.hi.next(srate);

    out *= 0.5;

    const bpm = self.getTempo();
    if (self.running)
        @atomicStore(f32, &self.phase, @mod(self.phase + bpm / (4 * 60 * srate), 1), .seq_cst);
    return out;
}

pub inline fn getPhase(self: *@This()) f32 {
    return @atomicLoad(f32, &self.phase, .seq_cst);
}

pub inline fn getTempo(self: *@This()) f32 {
    return @atomicLoad(f32, &self.bpm, .seq_cst);
}

pub inline fn setTempo(self: *@This(), bpm: f32) void {
    @atomicStore(f32, &self.bpm, bpm, .seq_cst);
}

pub inline fn changeTempo(self: *@This(), change: f32) void {
    const bpm = @atomicLoad(f32, &self.bpm, .seq_cst);
    const new = @min(maxtempo, @max(mintempo, bpm + change));
    @atomicStore(f32, &self.bpm, new, .seq_cst);
}

pub fn startstop(self: *@This()) void {
    @atomicStore(bool, &self.toggle_running, true, .seq_cst);
}

pub fn isRunning(self: *@This()) bool {
    return @atomicLoad(bool, &self.running, .seq_cst);
}
