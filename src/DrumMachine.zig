const samples = @import("samples.zig");
const DrumMachine = @This();
const Mixer = @import("Mixer.zig");
const midi = @import("midi.zig");
const Accessor = @import("Accessor.zig").Accessor;

pub const Params = struct {
    non_accent_level: f32 = 0.75,
    pub usingnamespace Accessor(@This());
};

channel: u4,
params: Params = .{},

bd: samples.Player = .{},
sd: samples.Player = .{},
hh: samples.Player = .{},
lt: samples.Player = .{},
ht: samples.Player = .{},
cy: samples.Player = .{},
xx: samples.Player = .{},
yy: samples.Player = .{},

pub inline fn next(self: *DrumMachine, mixer: *Mixer, srate: f32) void {
    mixer.channels[2].in = self.bd.next(srate);
    mixer.channels[3].in = self.sd.next(srate);
    mixer.channels[4].in = self.hh.next(srate);
    mixer.channels[5].in = self.lt.next(srate) + self.ht.next(srate);
    mixer.channels[6].in = self.cy.next(srate);
    mixer.channels[7].in = self.xx.next(srate);
    mixer.channels[8].in = self.yy.next(srate);
}

pub fn handleMidiEvent(self: *DrumMachine, event: midi.Event) void {
    if ((event.channel() orelse return) != self.channel) return;

    switch (event) {
        .note_on => |e| {
            if (e.velocity == 0) return;
            const lev: f32 = if (e.velocity < 96)
                self.params.get(.non_accent_level)
            else
                1;
            switch (e.pitch) {
                32 => self.bd.trigger(samples.bd, lev),
                33 => self.sd.trigger(samples.sd, lev),
                34 => self.hh.trigger(samples.ch, lev),
                35 => self.hh.trigger(samples.oh, lev),
                36 => self.hh.trigger(samples.choh, lev),
                37 => self.lt.trigger(samples.lo, lev),
                38 => self.ht.trigger(samples.hi, lev),
                39 => self.cy.trigger(samples.cy, lev),
                40 => {}, // xx
                41 => {}, // yy
                else => {},
            }
        },
        else => {},
    }
}
