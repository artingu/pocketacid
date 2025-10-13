const PDBass = @import("PDBass.zig");
const BassSeq = @import("BassSeq.zig");
const MidiBuf = @import("MidiBuf.zig");

const maxtempo = 300;
const mintempo = 1;

midibuf: *MidiBuf,
phase: f32 = 0,
bpm: f32 = 120,
startrow: u8 = 0,

bs: BassSeq = .{
    .patterns = &@import("state.zig").bass_patterns,
    .arrangement = &@import("state.zig").bass1_arrange,
    .channel = 0,
},
pdbass: PDBass = .{},

running: bool = false,
toggle_running: bool = false,

pub fn everyBuffer(self: *@This()) void {
    if (self.bs.midibuf == null) self.bs.midibuf = self.midibuf;
    if (@atomicRmw(bool, &self.toggle_running, .Xchg, false, .seq_cst)) {
        if (self.running) {
            @atomicStore(bool, &self.running, false, .seq_cst);
            self.bs.stop();
        } else {
            const startrow = @atomicLoad(u8, &self.startrow, .seq_cst);
            @atomicStore(bool, &self.running, true, .seq_cst);
            self.phase = 1;
            self.bs.start(startrow);
        }
    }

    for (self.midibuf.emit()) |event| {
        self.pdbass.handleMidiEvent(event);
    }
}

pub fn next(self: *@This(), srate: f32) f32 {
    const bpm = self.getTempo();

    self.phase += 24 * bpm / (60 * srate);
    while (self.phase >= 1) {
        self.bs.tick();
        self.phase -= 1;
    }
    for (self.midibuf.emit()) |event| {
        self.pdbass.handleMidiEvent(event);
    }
    return self.pdbass.next(srate) * 0.5;
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
