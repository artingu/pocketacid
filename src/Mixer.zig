const std = @import("std");

pub const Channels = struct {
    pub const bass1 = 0;
    pub const bass2 = 1;
};

pub const nchannels = 9;

const Mixer = @This();

pub const Frame = struct {
    left: f32 = 0,
    right: f32 = 0,

    fn add(self: *Frame, other: Frame) void {
        self.left += other.left;
        self.right += other.right;
    }
};

const Channel = struct {
    label: []const u8,
    level: u8 = 0xc0,
    pan: u8 = 0x80,

    in: f32 = 0,

    inline fn mix(self: *Channel) Frame {
        defer self.in = 0;

        const level = @as(f32, @floatFromInt(@atomicLoad(u8, &self.level, .seq_cst))) / 0x100;
        const pan = @as(f32, @floatFromInt(@atomicLoad(u8, &self.pan, .seq_cst))) / 0x100;

        const attenuated = self.in * level * level;

        const angle: f32 = pan * (std.math.pi / @as(f32, 2));

        return .{
            .left = attenuated * @cos(angle),
            .right = attenuated * @sin(angle),
        };
    }
};

channels: [nchannels]Channel,

pub fn mix(self: *Mixer) Frame {
    var out = Frame{};
    for (&self.channels) |*channel| out.add(channel.mix());
    return out;
}
