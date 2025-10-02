const pi = @import("std").math.pi;

pub fn pdhalf(phase: f32, x: f32, y: f32, n: u4, m: u4, o: f32) f32 {
    const bent = bend(phase, x, y, n);
    return @sin((o + bent) * @as(f32, @floatFromInt(m)) * 2 * pi);
}

inline fn bend(phase: f32, w: f32, h: f32, n: u4) f32 {
    return @mod(single(phase, w, h) / @as(f32, @floatFromInt(n)), 1);
}

inline fn single(phase: f32, w: f32, h: f32) f32 {
    const pm = @mod(phase, 1);
    return @floor(phase) + if (pm < w)
        pm * (h / w)
    else
        (pm - w) * ((1 - h) / (1 - w)) + h;
}
