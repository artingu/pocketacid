const DrumPattern = @import("DrumPattern.zig");
const MidiBuf = @import("MidiBuf.zig");
const DrumSeq = @This();
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const Queued = @import("Queued.zig").Queued;
const Kit = @import("Kit.zig");

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

    const pattern = &self.patterns.*[self.current_pattern];
    const kit_id = @atomicLoad(Kit.Id, &pattern.kit, .seq_cst);
    const step = pattern.steps[self.step].copy();
    self.updatePlaybackInfo();

    if (self.steptick == 0) {
        self.triggerDrums(step, kit_id);
    }

    if (self.steptick == 3 and step.rr) {
        self.trig(step, 63, kit_id);
        self.trig(step, 0, kit_id);
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

fn triggerDrums(self: *const DrumSeq, d: DrumPattern.Step, kit_id: Kit.Id) void {
    self.trig(d, if (d.ac) 127 else 63, kit_id);
    self.trig(d, 0, kit_id);
}

fn trig(self: *const DrumSeq, d: DrumPattern.Step, vel: u7, kit_id: Kit.Id) void {
    if (d.bd) self.note(0 + kit_id.offset(), vel);
    if (d.sd) self.note(1 + kit_id.offset(), vel);
    if (d.ch and d.oh)
        self.note(4 + kit_id.offset(), vel)
    else if (d.ch)
        self.note(2 + kit_id.offset(), vel)
    else if (d.oh)
        self.note(3 + kit_id.offset(), vel);
    if (d.lt) self.note(5 + kit_id.offset(), vel);
    if (d.ht) self.note(6 + kit_id.offset(), vel);
    if (d.cy) self.note(7 + kit_id.offset(), vel);
    if (d.xx) self.note(8 + kit_id.offset(), vel);
    if (d.yy) self.note(9 + kit_id.offset(), vel);
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
