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
pub fn drive(in: f32, level: u8) f32 {
    const l: f32 = @as(f32, @floatFromInt(level)) / 0xff;

    const a = (1 - @abs(in));
    const max = std.math.copysign(1 - a * a * a, in);

    return (1 - l) * @min(1, @max(-1, in)) + l * max;
}
