const std = @import("std");
const sdl = @import("sdl.zig");

const DumbPool = @import("dumbpool.zig").DumbPool;
const Pool = DumbPool(*sdl.GameController, 32);

p: Pool = Pool.init(),

pub fn openAll(self: *@This()) void {
    const njoy = sdl.numJoysticks();
    if (njoy < 0) return;

    for (0..@intCast(njoy)) |id| {
        if (0 != sdl.isGameController(@intCast(id)))
            self.open(@intCast(id));
    }
}

pub fn closeAll(self: *@This()) void {
    var i = self.p.iter();
    while (i.next()) |v| {
        sdl.gameControllerClose(v.*);
        self.p.free(v);
    }
}

pub fn open(self: *@This(), id: sdl.JoystickID) void {
    if (self.has(id)) return;
    const controller = sdl.gameControllerOpen(id) orelse return;
    const c = self.p.alloc() catch return;
    c.* = controller;

    std.debug.print("added game controller {s}\n", .{sdl.gameControllerName(controller)});
    std.debug.print("mapping:\n{s}\n", .{sdl.gameControllerMapping(controller)});
}

pub fn close(self: *@This(), id: sdl.JoystickID) void {
    var i = self.p.iter();
    while (i.next()) |v| {
        const joystick = sdl.gameControllerGetJoystick(v.*) orelse continue;
        const joystick_id = sdl.joystickInstanceID(joystick);
        if (id != joystick_id) continue;
        self.p.free(v);
        return;
    }
}

pub fn has(self: *@This(), id: sdl.JoystickID) bool {
    var i = self.p.iter();
    while (i.next()) |v| {
        const joystick = sdl.gameControllerGetJoystick(v.*) orelse continue;
        const joystick_id = sdl.joystickInstanceID(joystick);
        if (id == joystick_id) return true;
    }
    return false;
}
