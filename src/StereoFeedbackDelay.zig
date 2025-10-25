const FractionalDelayLine = @import("FractionalDelayLine.zig");
const Accessor = @import("Accessor.zig").Accessor;
const Frame = @import("Mixer.zig").Frame;
const Smoother = @import("Smoother.zig");

const smooth_time = 0.5;

pub const Params = struct {
    time: u8 = 0x30,
    feedback: u8 = 0x80,
    duck: u8 = 0,

    pub usingnamespace Accessor(@This());
};

left: FractionalDelayLine,
right: FractionalDelayLine,

params: Params = .{},
smoothed_delay_time: Smoother = .{},

pub fn next(self: *@This(), in: Frame, bpm: f32, duck: f32, srate: f32) Frame {
    const time = @as(f32, @floatFromInt(self.params.get(.time))) / 16;
    const feedback = @as(f32, @floatFromInt(self.params.get(.feedback))) / 0x100;
    const duck_level = @as(f32, @floatFromInt(self.params.get(.duck))) / 0xff;

    const smoothed = self.smoothed_delay_time.next(calcDelayTime(time, bpm), smooth_time, srate);

    const prev_left = self.left.out(smoothed * srate * 1.01);
    const prev_right = self.right.out(smoothed * srate * 0.99);

    self.left.feed(prev_left * feedback + in.left);
    self.right.feed(prev_right * feedback + in.right);

    const total_duck = (1 - duck_level) + duck * duck_level;

    return .{ .left = prev_left * total_duck, .right = prev_right * total_duck };
}

pub fn calcDelayTime(steps: f32, bpm: f32) f32 {
    const steps_per_second = 4 * bpm / 60;
    return steps / steps_per_second;
}
