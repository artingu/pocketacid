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

const std = @import("std");

current_srate: f32 = 0,
current_time: f32 = -1,
a: f32 = 0,
z: f32 = 0,

pub fn next(self: *@This(), in: f32, time: f32, srate: f32) f32 {
    if (srate != self.current_srate or time != self.current_time) {
        self.a = std.math.exp(-std.math.tau / (time * srate));
        self.current_srate = srate;
        self.current_time = time;
    }

    const b = 1 - self.a;
    self.z = (in * b) + (self.z * self.a);
    return self.z;
}

pub fn short(self: *@This(), in: f32) void {
    self.z = in;
}
