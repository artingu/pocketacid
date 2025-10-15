const PDBass = @import("PDBass.zig");
const BassSeq = @import("BassSeq.zig");
const MidiBuf = @import("MidiBuf.zig");

const maxtempo = 300;
const mintempo = 1;

midibuf: *MidiBuf,
phase: f32 = 0,
bpm: f32 = 120,
startrow: u8 = 0,

bs1: BassSeq = .{
    .patterns = &@import("state.zig").bass_patterns,
    .arrangement = &@import("state.zig").bass1_arrange,
    .channel = 0,
},
bs2: BassSeq = .{
    .patterns = &@import("state.zig").bass_patterns,
    .arrangement = &@import("state.zig").bass2_arrange,
    .channel = 1,
},
pdbass1: PDBass = .{ .params = .{ .channel = 0 } },
pdbass2: PDBass = .{ .params = .{ .channel = 1 } },

running: bool = false,
toggle_running: bool = false,

pub fn everyBuffer(self: *@This()) void {
    if (self.bs1.midibuf == null) self.bs1.midibuf = self.midibuf;
    if (self.bs2.midibuf == null) self.bs2.midibuf = self.midibuf;
    if (@atomicRmw(bool, &self.toggle_running, .Xchg, false, .seq_cst)) {
        if (self.running) {
            @atomicStore(bool, &self.running, false, .seq_cst);
            self.bs1.stop();
            self.bs2.stop();
        } else {
            const startrow = @atomicLoad(u8, &self.startrow, .seq_cst);
            @atomicStore(bool, &self.running, true, .seq_cst);
            self.phase = 1;
            self.bs1.start(startrow);
            self.bs2.start(startrow);
        }
    }

    for (self.midibuf.emit()) |event| {
        self.pdbass1.handleMidiEvent(event);
        self.pdbass2.handleMidiEvent(event);
    }
}

pub fn next(self: *@This(), srate: f32) f32 {
    const bpm = self.getTempo();

    self.phase += 24 * bpm / (60 * srate);
    while (self.phase >= 1) {
        self.bs1.tick();
        self.bs2.tick();
        self.phase -= 1;
    }
    for (self.midibuf.emit()) |event| {
        self.pdbass1.handleMidiEvent(event);
        self.pdbass2.handleMidiEvent(event);
    }
    return self.pdbass1.next(srate) * 0.5 + self.pdbass2.next(srate) * 0.5;
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

pub fn startstop(self: *@This(), startrow: u8) void {
    @atomicStore(u8, &self.startrow, startrow, .seq_cst);
    @atomicStore(bool, &self.toggle_running, true, .seq_cst);
}

pub fn isRunning(self: *@This()) bool {
    return @atomicLoad(bool, &self.running, .seq_cst);
}
