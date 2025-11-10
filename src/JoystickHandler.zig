// Copyright (C) 2025  Philip Linde
//
// This file is part of corrode.
//
// corrode is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// corrode is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with corrode.  If not, see <https://www.gnu.org/licenses/>.

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
