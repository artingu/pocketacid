const DrumPattern = @import("DrumPattern.zig");
const MidiBuf = @import("MidiBuf.zig");
const DrumSeq = @This();
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const Queued = @import("Queued.zig").Queued;

patterns: *[256]DrumPattern,
arrangement: *[256]u8,
midibuf: ?*MidiBuf = null,

start_arrangement_idx: u8 = 0,
arrangement_idx: u8 = 0,
queued_info: Queued = .{},

current_pattern: u8 = 0xff,

steptick: u3 = 0,
step: u5 = 0,
running: bool = false,

info: PlaybackInfo = .{},

channel: u4,

const choh = 36;

pub fn tick(self: *DrumSeq) void {
    if (!self.running) return;

    const step = self.patterns.*[self.current_pattern].steps[self.step].copy();
    self.updatePlaybackInfo();

    if (self.steptick == 0) {
        self.triggerDrums(step);
    }

    if (self.steptick == 3 and step.rr) {
        self.trig(step, 63);
        self.trig(step, 0);
    }

    self.steptick += 1;
    if (self.steptick >= 6) {
        self.steptick = 0;
        self.step += 1;

        if (self.step >= self.patterns.*[self.current_pattern].length()) {
            self.step = 0;

            if (self.current_pattern != 0xff) {
                self.arrangement_idx +%= 1;
                const cur_pattern = @atomicLoad(
                    u8,
                    &self.arrangement[self.arrangement_idx],
                    .seq_cst,
                );
                if (cur_pattern == 0xff) {
                    self.arrangement_idx = self.start_arrangement_idx;
                    @atomicStore(Queued, &self.queued_info, .{}, .seq_cst);
                }
                self.updateCurrentPattern();
            }
        }
    }
}

fn note(self: *const DrumSeq, p: u7, v: u7) void {
    if (self.midibuf) |mb| mb.feed(.{ .note_on = .{
        .channel = self.channel,
        .pitch = p,
        .velocity = v,
    } });
}

fn triggerDrums(self: *const DrumSeq, d: DrumPattern.Step) void {
    self.trig(d, if (d.ac) 127 else 63);
    self.trig(d, 0);
}

fn trig(self: *const DrumSeq, d: DrumPattern.Step, vel: u7) void {
    if (d.bd) self.note(drumPitch(.bd), vel);
    if (d.sd) self.note(drumPitch(.sd), vel);
    if (d.ch and d.oh)
        self.note(choh, vel)
    else if (d.ch)
        self.note(drumPitch(.ch), vel)
    else if (d.oh)
        self.note(drumPitch(.oh), vel);
    if (d.lt) self.note(drumPitch(.lt), vel);
    if (d.ht) self.note(drumPitch(.ht), vel);
    if (d.cy) self.note(drumPitch(.cy), vel);
    if (d.xx) self.note(drumPitch(.xx), vel);
    if (d.yy) self.note(drumPitch(.yy), vel);
}

inline fn updatePlaybackInfo(self: *DrumSeq) void {
    @atomicStore(PlaybackInfo, &self.info, .{
        .arrangement_row = self.arrangement_idx,
        .pattern = self.current_pattern,
        .step = self.step,
        .running = self.running and self.current_pattern != 0xff,
    }, .seq_cst);
}

inline fn updateCurrentPattern(self: *DrumSeq) void {
    const arr_idx = self.arrangement_idx;
    self.current_pattern = @atomicLoad(u8, &self.arrangement[arr_idx], .seq_cst);
}

pub inline fn playbackInfo(self: *const DrumSeq) PlaybackInfo {
    return @atomicLoad(PlaybackInfo, &self.info, .seq_cst);
}

pub fn enqueue(self: *DrumSeq, idx: u8) void {
    if (@atomicLoad(u8, &self.arrangement.*[idx], .seq_cst) == 0xff) return;
    self.start_arrangement_idx = idx;
    @atomicStore(Queued, &self.queued_info, .{
        .nothing = false,
        .row = idx,
    }, .seq_cst);
}

pub fn queued(self: *const DrumSeq) ?u8 {
    const q = @atomicLoad(Queued, &self.queued_info, .seq_cst);
    const pi = self.playbackInfo();

    if (!pi.running) return null;
    if (q.nothing) return null;
    return q.row;
}

pub fn start(self: *DrumSeq, idx: u8) void {
    self.start_arrangement_idx = idx;
    self.arrangement_idx = idx;
    self.updateCurrentPattern();

    self.step = 0;
    self.steptick = 0;

    self.running = true;
}

pub fn stop(self: *DrumSeq) void {
    self.running = false;
    self.updatePlaybackInfo();
    @atomicStore(Queued, &self.queued_info, .{}, .seq_cst);
}

fn drumPitch(d: DrumPattern.DrumType) u7 {
    return switch (d) {
        .bd => 32,
        .sd => 33,
        .ch => 34,
        .oh => 35,
        // ch+oh is 36
        .lt => 37,
        .ht => 38,
        .cy => 39,
        .xx => 40,
        .yy => 41,
        .ac => 0,
        .rr => 0,
    };
}
