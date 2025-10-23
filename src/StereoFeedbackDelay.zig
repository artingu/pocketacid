const FractionalDelayLine = @import("FractionalDelayLine.zig");
const Accessor = @import("Accessor.zig").Accessor;
const Frame = @import("Mixer.zig").Frame;
const Smoother = @import("Smoother.zig");

const smooth_time = 0.5;

const Params = struct {
    pub usingnamespace Accessor(@This());
    time: f32 = 3,
    feedback: f32 = 0.5,
};

left: FractionalDelayLine,
right: FractionalDelayLine,

params: Params = .{},
smoothed_delay_time: Smoother = .{},

pub fn next(self: *@This(), in: Frame, bpm: f32, srate: f32) Frame {
    const time = self.params.get(.time);

    const smoothed = self.smoothed_delay_time.next(calcDelayTime(time, bpm), smooth_time, srate);

    const feedback = self.params.get(.feedback);
    const prev_left = self.left.out(smoothed * srate * 1.01);
    const prev_right = self.right.out(smoothed * srate * 0.99);

    self.left.feed(prev_left * feedback + in.left);
    self.right.feed(prev_right * feedback + in.right);

    return .{ .left = prev_left, .right = prev_right };
}

pub fn calcDelayTime(steps: f32, bpm: f32) f32 {
    const steps_per_second = 4 * bpm / 60;

    return steps / steps_per_second;
}
