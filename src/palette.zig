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

const RGB = @import("rgb.zig").RGB;

pub const pal = [16]RGB{
    RGB.init(0, 0, 0),
    RGB.init(29, 43, 83),
    RGB.init(126, 37, 83),
    RGB.init(0, 135, 81),

    RGB.init(171, 82, 54),
    RGB.init(95, 87, 79),
    RGB.init(194, 195, 199),
    RGB.init(255, 241, 232),

    RGB.init(255, 0, 77),
    RGB.init(255, 163, 0),
    RGB.init(255, 236, 39),
    RGB.init(0, 228, 54),

    RGB.init(41, 173, 255),
    RGB.init(131, 118, 156),
    RGB.init(255, 119, 168),
    RGB.init(255, 204, 170),
};
