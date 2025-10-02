const colors = @import("colors.zig");

const DrumTrack = @import("DrumTrack.zig");
const DrumPattern = @import("DrumPattern.zig");
const TextMatrix = @import("TextMatrix.zig");
const InputState = @import("ButtonHandler.zig").States;
const Sys = @import("Sys.zig");

const hex = "0123456789abcdef";

const maxtempo = 9999;
const mintempo = 1;

const Selected = enum { bd, sd, ch, oh, lo, hi, cy };

pattern: *DrumPattern,
selected: Selected = .bd,
idx: usize = 0,
buffer: DrumTrack.Step = .{ .gates = 1, .velocity = 0xf },
blink: f32 = 0,

pub fn handle(self: *@This(), input: InputState) void {
    const step = self.selectedStep();
    const track = self.selectedTrack();

    if (input.hold.any()) self.blink = 0;

    if (input.press.b and step.active()) {
        self.buffer = step.copy();
        step.delete();
    }
    if (input.press.a and !step.active()) step.assume(self.buffer);
    if (input.release.a and step.active()) self.buffer = step.copy();

    if (input.combo("a+up")) step.incVelocity();
    if (input.combo("a+down")) step.decVelocity();
    if (input.combo("a+right")) step.incGates();
    if (input.combo("a+left")) step.decGates();

    if (input.combo("x+up")) track.incDiv();
    if (input.combo("x+down")) track.decDiv();
    if (input.combo("x+right")) track.incLen();
    if (input.combo("x+left")) track.decLen();

    if (input.combo("l+up")) Sys.sound_engine.changeTempo(10);
    if (input.combo("l+down")) Sys.sound_engine.changeTempo(-10);
    if (input.combo("l+right")) Sys.sound_engine.changeTempo(1);
    if (input.combo("l+left")) Sys.sound_engine.changeTempo(-1);

    if (input.combo("up")) self.prevSelected();
    if (input.combo("down")) self.nextSelected();
    if (input.combo("right")) self.nextIdx();
    if (input.combo("left")) self.prevIdx();
}

fn nextIdx(self: *@This()) void {
    self.idx = (self.idx + 1) % self.selectedTrack().len;
}

fn prevIdx(self: *@This()) void {
    self.idx = if (self.idx != 0)
        (self.idx - 1) % self.selectedTrack().len
    else
        self.selectedTrack().len - 1;
}

fn nextSelected(self: *@This()) void {
    self.selected = switch (self.selected) {
        .bd => .sd,
        .sd => .ch,
        .ch => .oh,
        .oh => .lo,
        .lo => .hi,
        .hi => .cy,
        .cy => .bd,
    };

    const len = self.selectedTrack().len;
    self.idx = if (self.idx < len) self.idx else len - 1;
}

fn prevSelected(self: *@This()) void {
    self.selected = switch (self.selected) {
        .bd => .cy,
        .sd => .bd,
        .ch => .sd,
        .oh => .ch,
        .lo => .oh,
        .hi => .lo,
        .cy => .hi,
    };

    const len = self.selectedTrack().len;
    self.idx = if (self.idx < len) self.idx else len - 1;
}

fn selectedStep(self: *@This()) *DrumTrack.Step {
    const track = self.selectedTrack();
    return &track.steps[self.idx];
}

fn selectedTrack(self: *@This()) *DrumTrack {
    return switch (self.selected) {
        .bd => &self.pattern.bd,
        .sd => &self.pattern.sd,
        .ch => &self.pattern.ch,
        .oh => &self.pattern.oh,
        .lo => &self.pattern.lo,
        .hi => &self.pattern.hi,
        .cy => &self.pattern.cy,
    };
}

pub fn display(self: *@This(), tm: *TextMatrix, x: usize, y: usize, dt: f32) void {
    tm.puts(x, y + 0 * 3, colors.normal, "BD");
    tm.print(x, y + 0 * 3 + 1, colors.time, "{x}/{x}", .{ self.pattern.bd.len & 0xf, self.pattern.bd.div & 0xf });

    tm.puts(x, y + 1 * 3, colors.normal, "SD");
    tm.print(x, y + 1 * 3 + 1, colors.time, "{x}/{x}", .{ self.pattern.sd.len & 0xf, self.pattern.sd.div & 0xf });

    tm.puts(x, y + 2 * 3, colors.normal, "CH");
    tm.print(x, y + 2 * 3 + 1, colors.time, "{x}/{x}", .{ self.pattern.ch.len & 0xf, self.pattern.ch.div & 0xf });

    tm.puts(x, y + 3 * 3, colors.normal, "OH");
    tm.print(x, y + 3 * 3 + 1, colors.time, "{x}/{x}", .{ self.pattern.oh.len & 0xf, self.pattern.oh.div & 0xf });

    tm.puts(x, y + 4 * 3, colors.normal, "LO");
    tm.print(x, y + 4 * 3 + 1, colors.time, "{x}/{x}", .{ self.pattern.lo.len & 0xf, self.pattern.lo.div & 0xf });

    tm.puts(x, y + 5 * 3, colors.normal, "HI");
    tm.print(x, y + 5 * 3 + 1, colors.time, "{x}/{x}", .{ self.pattern.hi.len & 0xf, self.pattern.hi.div & 0xf });

    tm.puts(x, y + 6 * 3, colors.normal, "CY");
    tm.print(x, y + 6 * 3 + 1, colors.time, "{x}/{x}", .{ self.pattern.cy.len & 0xf, self.pattern.cy.div & 0xf });

    const on = @mod(self.blink * 4, 1) < 0.5;

    displayTrack(self.pattern.bd, tm, x + 4, y + 0 * 3, if (self.selected == .bd and on) self.idx else null, Sys.sound_engine.ds.bd.getIdx());
    displayTrack(self.pattern.sd, tm, x + 4, y + 1 * 3, if (self.selected == .sd and on) self.idx else null, Sys.sound_engine.ds.sd.getIdx());
    displayTrack(self.pattern.ch, tm, x + 4, y + 2 * 3, if (self.selected == .ch and on) self.idx else null, Sys.sound_engine.ds.ch.getIdx());
    displayTrack(self.pattern.oh, tm, x + 4, y + 3 * 3, if (self.selected == .oh and on) self.idx else null, Sys.sound_engine.ds.oh.getIdx());
    displayTrack(self.pattern.lo, tm, x + 4, y + 4 * 3, if (self.selected == .lo and on) self.idx else null, Sys.sound_engine.ds.lo.getIdx());
    displayTrack(self.pattern.hi, tm, x + 4, y + 5 * 3, if (self.selected == .hi and on) self.idx else null, Sys.sound_engine.ds.hi.getIdx());
    displayTrack(self.pattern.cy, tm, x + 4, y + 6 * 3, if (self.selected == .cy and on) self.idx else null, Sys.sound_engine.ds.cy.getIdx());

    self.blink = @mod(self.blink + dt, 1);
}

fn displayTrack(track: DrumTrack, tm: *TextMatrix, x: usize, y: usize, highlighted: ?usize, playstep: ?usize) void {
    for (&track.steps, 0..) |*step, i| {
        var color: u8 = if (i < track.len) colors.normal else colors.inactive;
        if (playstep) |s| {
            if (i == s) color = colors.playing;
        }
        if (highlighted) |s| {
            // Swap nybbles to invert color
            if (i == s) color = (color >> 4) | ((color & 0xf) << 4);
        }

        tm.putch(x + i, y, color, if (step.gates > 0) hex[step.gates & 0xf] else '_');
        tm.putch(x + i, y + 1, color, if (step.gates > 0) hex[step.velocity & 0xf] else '.');
    }
}
