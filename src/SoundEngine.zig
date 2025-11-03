const PDBass = @import("PDBass.zig");
const BassSeq = @import("BassSeq.zig");
const DrumSeq = @import("DrumSeq.zig");
const MidiBuf = @import("MidiBuf.zig");
const Mixer = @import("Mixer.zig");
const DrumMachine = @import("DrumMachine.zig");
const Ducker = @import("Ducker.zig");
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const calcDrive = @import("drive.zig").drive;
const song = @import("song.zig");
const GlobalParams = @import("Params.zig");
const Accessor = @import("Accessor.zig").Accessor;

const maxtempo = 300;
const mintempo = 1;

var delay_buf_left: [48000 * 10]f32 = undefined;
var delay_buf_right: [48000 * 10]f32 = undefined;

pub const Params = struct {
    bpm: i16 = 120,
    drive: u8 = 0,

    pub usingnamespace Accessor(@This());

    pub inline fn changeTempo(self: *@This(), change: i16) void {
        const bpm = self.get(.bpm);
        const new = @min(maxtempo, @max(mintempo, bpm + change));
        self.set(.bpm, new);
    }
};

midibuf: *MidiBuf,
params: *const Params = undefined,

phase: f32 = 0,
startrow: u8 = 0,

bs1: BassSeq = .{
    .patterns = &song.bass_patterns,
    .arrangement = &song.bass1_arrange,
    .channel = 0,
},
bs2: BassSeq = .{
    .patterns = &song.bass_patterns,
    .arrangement = &song.bass2_arrange,
    .channel = 1,
},
ds: DrumSeq = .{
    .patterns = &song.drum_patterns,
    .arrangement = &song.drum_arrange,
    .channel = 2,
},

pdbass1: PDBass = .{ .channel = 0, .params = undefined },
pdbass2: PDBass = .{ .channel = 1, .params = undefined },
drums: DrumMachine = .{ .channel = 2, .params = undefined },

delay: StereoFeedbackDelay = .{
    .left = .{ .delay = .{ .buffer = &delay_buf_left } },
    .right = .{ .delay = .{ .buffer = &delay_buf_right } },
    .params = undefined,
},

cmd: Cmd = .{},

mixer: Mixer = .{ .channels = .{
    .{ .label = "B1", .params = undefined },
    .{ .label = "B2", .params = undefined },
    .{ .label = "bd", .params = undefined },
    .{ .label = "sd", .params = undefined },
    .{ .label = "hh", .params = undefined },
    .{ .label = "tm", .params = undefined },
    .{ .label = "cy", .params = undefined },
    .{ .label = "xx", .params = undefined },
    .{ .label = "yy", .params = undefined },
} },

running: bool = false,
toggle_running: bool = false,

const CmdType = enum(u2) { none, startstop, enqueue };
const Cmd = packed struct {
    t: CmdType = .none,
    row: u8 = 0,
    _: u6 = 0,
};

pub fn init(self: *@This(), params: *const GlobalParams) void {
    for (0..delay_buf_left.len) |i| delay_buf_left[i] = 0;
    for (0..delay_buf_right.len) |i| delay_buf_right[i] = 0;
    for (0..Mixer.nchannels) |i| self.mixer.channels[i].params = &params.mixer[i];

    self.params = &params.engine;
    self.pdbass1.params = &params.bass1;
    self.pdbass2.params = &params.bass2;
    self.drums.params = &params.drums;
    self.delay.params = &params.delay;

    self.bs1.midibuf = self.midibuf;
    self.bs2.midibuf = self.midibuf;
    self.ds.midibuf = self.midibuf;
}

pub fn resetDelay(self: *@This()) void {
    const time = @as(f32, @floatFromInt(self.delay.params.get(.time))) / 16;
    const tempo: f32 = @floatFromInt(self.params.get(.bpm));
    self.delay.smoothed_delay_time.short(StereoFeedbackDelay.calcDelayTime(time, tempo));
}

pub fn everyBuffer(self: *@This()) void {
    const cmd = @atomicRmw(Cmd, &self.cmd, .Xchg, .{}, .seq_cst);
    cmdswitch: switch (cmd.t) {
        .startstop => {
            const running = @atomicLoad(bool, &self.running, .seq_cst);
            if (running) {
                @atomicStore(bool, &self.running, false, .seq_cst);
                self.bs1.stop();
                self.bs2.stop();
                self.ds.stop();
            } else {
                @atomicStore(bool, &self.running, true, .seq_cst);
                self.phase = 1;
                self.bs1.start(cmd.row);
                self.bs2.start(cmd.row);
                self.ds.start(cmd.row);
            }
        },
        .enqueue => {
            if (!@atomicLoad(bool, &self.running, .seq_cst)) break :cmdswitch;
            self.bs1.enqueue(cmd.row);
            self.bs2.enqueue(cmd.row);
            self.ds.enqueue(cmd.row);
        },
        .none => {},
    }

    for (self.midibuf.emit()) |event| {
        self.pdbass1.handleMidiEvent(event);
        self.pdbass2.handleMidiEvent(event);
    }
}

pub fn next(self: *@This(), srate: f32) Mixer.Frame {
    const bpm: f32 = @floatFromInt(self.params.get(.bpm));

    self.phase += 24 * bpm / (60 * srate);
    while (self.phase >= 1) {
        self.bs1.tick();
        self.bs2.tick();
        self.ds.tick();
        self.phase -= 1;
    }
    for (self.midibuf.emit()) |event| {
        self.pdbass1.handleMidiEvent(event);
        self.pdbass2.handleMidiEvent(event);
        self.drums.handleMidiEvent(event);
    }

    // TODO can this be handled by DrumMachine itself?
    const duck = self.drums.ducker.next(self.drums.params.get(.duck_time), srate);

    // TODO better way of naming channel indices
    self.mixer.channels[0].in = self.pdbass1.next(srate);
    self.mixer.channels[1].in = self.pdbass2.next(srate);
    self.drums.next(&self.mixer, srate);

    var send: Mixer.Frame = .{};
    var out = self.mixer.mix(&send, duck);
    out.add(self.delay.next(send, bpm, duck, srate));

    const drive = self.params.get(.drive);
    return .{
        .left = calcDrive(out.left, drive),
        .right = calcDrive(out.right, drive),
    };
}

pub fn startstop(self: *@This(), row: u8) void {
    @atomicStore(Cmd, &self.cmd, .{
        .t = .startstop,
        .row = row,
    }, .seq_cst);
}

pub fn enqueue(self: *@This(), row: u8) void {
    @atomicStore(Cmd, &self.cmd, .{
        .t = .enqueue,
        .row = row,
    }, .seq_cst);
}

pub fn isRunning(self: *@This()) bool {
    return @atomicLoad(bool, &self.running, .seq_cst);
}
