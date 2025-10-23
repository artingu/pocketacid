const FractionalDelayLine = @import("FractionalDelayLine.zig");
const Accessor = @import("Accessor.zig").Accessor;
const Frame = @import("Mixer.zig").Frame;

const Params = struct {
    pub usingnamespace Accessor(@This());
    time: f32 = 0.5,
    feedback: f32 = 0.5,
};

left: FractionalDelayLine,
right: FractionalDelayLine,

params: Params = .{},

pub fn next(self: *@This(), in: Frame, srate: f32) Frame {
    const time = self.params.get(.time);
    const feedback = self.params.get(.feedback);
    const prev_left = self.left.out(time * srate * 1.01);
    const prev_right = self.right.out(time * srate * 0.99);

    self.left.feed(prev_left * feedback + in.left);
    self.right.feed(prev_right * feedback + in.right);

    return .{ .left = prev_left, .right = prev_right };
}
