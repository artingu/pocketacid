const samples = @import("samples.zig");
const Kit = @import("Kit.zig");
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
    non_accent_level: u8 = 0xc0,
    kit: Kit.Id = .R6,
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
                @as(f32, @floatFromInt(self.params.get(.non_accent_level))) / 0xff
            else
                1;

            const bdm = self.mutes.get(.bd);
            const sdm = self.mutes.get(.sd);
            const hhcym = self.mutes.get(.hhcy);
            const tmm = self.mutes.get(.tm);

            const kit = self.params.get(.kit).resolve();

            switch (e.pitch) {
                0 => if (!bdm) {
                    self.bd.trigger(kit.bd, lev);
                    self.ducker.trigger();
                },
                1 => if (!sdm) self.sd.trigger(kit.sd, lev),
                2 => if (!hhcym) self.hh.trigger(kit.ch, lev),
                3 => if (!hhcym) self.hh.trigger(kit.oh, lev),
                4 => if (!hhcym) self.hh.trigger(kit.choh, lev),
                5 => if (!tmm) self.lt.trigger(kit.lt, lev),
                6 => if (!tmm) self.ht.trigger(kit.ht, lev),
                7 => if (!hhcym) self.cy.trigger(kit.cy, lev),
                8 => self.xx.trigger(kit.xx, lev),
                9 => self.yy.trigger(kit.yy, lev),
                else => {},
            }
        },
        else => {},
    }
}
