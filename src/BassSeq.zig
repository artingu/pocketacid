const std = @import("std");
const BassPattern = @import("BassPattern.zig");
const MidiBuf = @import("MidiBuf.zig");
const BassSeq = @This();
const midi = @import("midi.zig");
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const Queued = @import("Queued.zig").Queued;

patterns: *[256]BassPattern,
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

curstep: BassPattern.Step = .{},
playing_note: ?u7 = null,

channel: u4,

fn noteOn(self: *BassSeq, pitch: u7, velocity: u7) void {
    const n: u8 = self.playing_note orelse 0xff;

    if (n != pitch) {
        if (self.midibuf) |mb| mb.feed(midi.Event{ .note_on = .{
            .channel = self.channel,
            .pitch = pitch,
            .velocity = velocity,
        } });
        self.maybeNoteOff();
    }

    self.playing_note = pitch;
}

fn maybeNoteOff(self: *BassSeq) void {
    if (self.playing_note) |pitch| {
        self.playing_note = null;

        if (self.midibuf) |mb| mb.feed(midi.Event{ .note_on = .{
            .channel = self.channel,
            .pitch = pitch,
            .velocity = 0,
        } });
    }
}
pub fn tick(self: *BassSeq) void {
    if (!self.running) return;

    self.updatePlaybackInfo();
    switch (self.steptick) {
        0 => {
            self.curstep = self.patterns.*[self.current_pattern].steps[self.step].copy();
            if (self.curstep.midi(self.patterns.*[self.current_pattern].getBase())) |curpitch|
                self.noteOn(curpitch, if (self.curstep.accent) 127 else 63);
        },
        3 => if (!self.curstep.slide) self.maybeNoteOff(),
        else => {},
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

inline fn updatePlaybackInfo(self: *BassSeq) void {
    @atomicStore(PlaybackInfo, &self.info, .{
        .arrangement_row = self.arrangement_idx,
        .pattern = self.current_pattern,
        .step = self.step,
        .running = self.running and self.current_pattern != 0xff,
    }, .seq_cst);
}

inline fn updateCurrentPattern(self: *BassSeq) void {
    const arr_idx = self.arrangement_idx;
    self.current_pattern = @atomicLoad(u8, &self.arrangement[arr_idx], .seq_cst);
}

pub inline fn playbackInfo(self: *const BassSeq) PlaybackInfo {
    return @atomicLoad(PlaybackInfo, &self.info, .seq_cst);
}

pub fn enqueue(self: *BassSeq, idx: u8) void {
    if (@atomicLoad(u8, &self.arrangement.*[idx], .seq_cst) == 0xff) return;
    self.start_arrangement_idx = idx;
    @atomicStore(Queued, &self.queued_info, .{
        .nothing = false,
        .row = idx,
    }, .seq_cst);
}

pub fn queued(self: *const BassSeq) ?u8 {
    const q = @atomicLoad(Queued, &self.queued_info, .seq_cst);
    const pi = self.playbackInfo();

    if (!pi.running) return null;
    if (q.nothing) return null;
    return q.row;
}

pub fn start(self: *BassSeq, idx: u8) void {
    self.start_arrangement_idx = idx;
    self.arrangement_idx = idx;
    self.updateCurrentPattern();

    self.step = 0;
    self.steptick = 0;

    self.running = true;
}

pub fn stop(self: *BassSeq) void {
    self.running = false;
    self.updatePlaybackInfo();
    self.maybeNoteOff();
    @atomicStore(Queued, &self.queued_info, .{}, .seq_cst);
}
