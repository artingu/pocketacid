const Accessor = @import("Accessor.zig").Accessor;

current: f32 = 1,

pub inline fn trigger(self: *@This()) void {
    self.current = 0;
}

pub fn next(self: *@This(), time_param: u8, srate: f32) f32 {
    const base_time: f32 = @as(f32, @floatFromInt(time_param)) / 0xff;
    const time = base_time * 0.5 + 1 / 0x200;
    defer self.current = @min(self.current + 1 / (time * srate), 1.0);
    return self.current * self.current;
}
