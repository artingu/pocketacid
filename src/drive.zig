const std = @import("std");
pub fn drive(in: f32, level: u8) f32 {
    const l: f32 = @as(f32, @floatFromInt(level)) / 0xff;

    const a = (1 - @abs(in));
    const max = std.math.copysign(1 - a * a * a, in);

    return (1 - l) * @min(1, @max(-1, in)) + l * max;
}
