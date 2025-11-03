const std = @import("std");
const Accessor = @import("Accessor.zig").Accessor;

pub const Channels = struct {
    pub const bass1 = 0;
    pub const bass2 = 1;
};

pub const nchannels = 9;

const Mixer = @This();

pub const Frame = struct {
    left: f32 = 0,
    right: f32 = 0,

    pub fn add(self: *Frame, other: Frame) void {
        self.left += other.left;
        self.right += other.right;
    }
};

pub const Channel = struct {
    pub const Params = struct {
        level: u8 = 0xc0,
        pan: u8 = 0x80,
        send: u8 = 0x00,
        duck: u8 = 0x00,

        pub usingnamespace Accessor(@This());
    };

    label: []const u8,
    params: *const Params,

    in: f32 = 0,

    inline fn mix(self: *Channel, duck: f32) Frame {
        defer self.in = 0;

        const level = @as(f32, @floatFromInt(self.params.get(.level))) / 0xff;
        const pan = @as(f32, @floatFromInt(self.params.get(.pan))) / 0x100;
        const duck_level = @as(f32, @floatFromInt(self.params.get(.duck))) / 0xff;

        const total_duck = (1 - duck_level) + duck * duck_level;

        const attenuated = self.in * level * level * total_duck;

        const angle: f32 = pan * (std.math.pi / @as(f32, 2));

        return .{
            .left = attenuated * @cos(angle),
            .right = attenuated * @sin(angle),
        };
    }
};

channels: [nchannels]Channel,

pub fn mix(self: *Mixer, send: *Frame, duck: f32) Frame {
    var out = Frame{};
    for (&self.channels) |*channel| {
        const mx = channel.mix(duck);

        const send_level = @as(f32, @floatFromInt(channel.params.get(.send))) / 0x100;

        out.add(mx);
        send.add(.{ .left = mx.left * send_level, .right = mx.right * send_level });
    }

    return out;
}
