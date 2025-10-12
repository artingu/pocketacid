const sdl = @import("sdl.zig");

lx: f32 = 0,
ly: f32 = 0,
rx: f32 = 0,
ry: f32 = 0,

deadzone: f32 = 0.2,

pub fn handle(self: *@This(), e: *sdl.Event) bool {
    switch (e.type) {
        sdl.CONTROLLERAXISMOTION => {
            const addr = switch (e.caxis.axis) {
                sdl.CONTROLLER_AXIS_LEFTX => &self.lx,
                sdl.CONTROLLER_AXIS_LEFTY => &self.ly,
                sdl.CONTROLLER_AXIS_RIGHTX => &self.rx,
                sdl.CONTROLLER_AXIS_RIGHTY => &self.ry,
                else => return false,
            };

            const v: f32 = @as(f32, @floatFromInt(e.caxis.value)) / 32767;

            if (v >= self.deadzone) {
                addr.* = v * (1 + self.deadzone) - self.deadzone;
            } else if (v <= -self.deadzone) {
                addr.* = v * (1 + self.deadzone) + self.deadzone;
            } else {
                addr.* = 0;
            }
            return true;
        },
        else => return false,
    }
}
