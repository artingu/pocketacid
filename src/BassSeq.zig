const std = @import("std");
const BassPattern = @import("BassPattern.zig");
const MidiBuf = @import("MidiBuf.zig");
const BassSeq = @This();

pattern: *BassPattern,
nextpattern: ?*BassPattern = null,
midibuf: ?*MidiBuf = null,

steptick: u3 = 0,
step: u5 = 0,
running: bool = false,

curstep: BassPattern.Step = .{},
playing_note: ?u7 = null,

basepitch: u7 = 40,

// Don't change during playback
channel: u4,

fn noteOn(self: *BassSeq, pitch: u7, velocity: u7) void {
    const n: u8 = self.playing_note orelse 0xff;

    if (n != pitch) {
        std.debug.print("Note on: {} {}\n", .{ pitch, velocity });
        if (self.midibuf) |mb| {
            mb.feedByte(@as(u8, 0x80) | self.channel);
            mb.feedByte(pitch);
            mb.feedByte(velocity);
        }
        self.maybeNoteOff();
    }

    self.playing_note = pitch;
}

fn maybeNoteOff(self: *BassSeq) void {
    if (self.playing_note) |p| {
        self.playing_note = null;

        std.debug.print("Note off: {}\n", .{p});
        if (self.midibuf) |mb| {
            mb.feedByte(@as(u8, 0x80) | self.channel);
            mb.feedByte(p);
            mb.feedByte(0);
        }
    }
}
pub fn tick(self: *BassSeq) void {
    if (!self.running) return;

    switch (self.steptick) {
        0 => {
            self.curstep = self.pattern.steps[self.step].copy();
            if (self.curstep.midi(@atomicLoad(u7, &self.basepitch, .seq_cst))) |curpitch|
                self.noteOn(curpitch, if (self.curstep.accent) 127 else 63);
        },
        3 => if (!self.curstep.slide) self.maybeNoteOff(),
        else => {},
    }

    self.steptick += 1;
    if (self.steptick >= 6) {
        self.steptick = 0;
        self.step += 1;

        if (self.step >= self.pattern.length()) {
            self.step = 0;
            if (self.nextpattern) |next| self.pattern = next;
        }
    }
}

pub fn start(self: *BassSeq) void {
    self.running = true;
    self.step = 0;
    self.steptick = 0;
    self.nextpattern = null;
}

pub fn stop(self: *BassSeq) void {
    self.running = false;
    self.maybeNoteOff();
}
