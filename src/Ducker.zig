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
