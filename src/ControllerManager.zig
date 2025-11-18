// Copyright (C) 2025  Philip Linde
//
// This file is part of Pocket Acid.
//
// Pocket Acid is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Pocket Acid is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Pocket Acid.  If not, see <https://www.gnu.org/licenses/>.

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
