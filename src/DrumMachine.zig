const samples = @import("samples.zig");
const DrumMachine = @This();
const Mixer = @import("Mixer.zig");
const midi = @import("midi.zig");
const Accessor = @import("Accessor.zig").Accessor;
const Ducker = @import("Ducker.zig");

pub const Mutes = packed struct(u8) {
    pub const Group = enum { bd, sd, hhcy, tm };

    bd: bool = false,
    sd: bool = false,
    hhcy: bool = false,
    tm: bool = false,

    _: u4 = 0,

    pub fn toggle(self: *Mutes, comptime group: Group) void {
        var new = @atomicLoad(Mutes, self, .seq_cst);
        switch (group) {
            inline else => |v| @field(new, @tagName(v)) = !@field(new, @tagName(v)),
        }
        @atomicStore(Mutes, self, new, .seq_cst);
    }

    pub fn get(self: *Mutes, comptime group: Group) bool {
        const copy = @atomicLoad(Mutes, self, .seq_cst);
        return switch (group) {
            inline else => |v| @field(copy, @tagName(v)),
        };
    }
};
pub const Params = struct {
    non_accent_level: f32 = 0.75,
    pub usingnamespace Accessor(@This());
};

channel: u4,
params: Params = .{},
ducker: Ducker = .{},

mutes: Mutes = .{},

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

            const bdm = self.mutes.get(.bd);
            const sdm = self.mutes.get(.sd);
            const hhcym = self.mutes.get(.hhcy);
            const tmm = self.mutes.get(.tm);
            switch (e.pitch) {
                32 => if (!bdm) {
                    self.bd.trigger(samples.bd, lev);
                    self.ducker.trigger();
                },
                33 => if (!sdm) self.sd.trigger(samples.sd, lev),
                34 => if (!hhcym) self.hh.trigger(samples.ch, lev),
                35 => if (!hhcym) self.hh.trigger(samples.oh, lev),
                36 => if (!hhcym) self.hh.trigger(samples.choh, lev),
                37 => if (!tmm) self.lt.trigger(samples.lo, lev),
                38 => if (!tmm) self.ht.trigger(samples.hi, lev),
                39 => if (!hhcym) self.cy.trigger(samples.cy, lev),
                40 => {}, // xx
                41 => {}, // yy
                else => {},
            }
        },
        else => {},
    }
}
