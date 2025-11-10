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
const Cell = @import("CharDisplay.zig").Cell;
const Attrib = @import("CharDisplay.zig").Attrib;
const RGB = @import("rgb.zig").RGB;

w: usize,
h: usize,
out: []Cell,
buf: [100]u8 = undefined,

pub fn clear(self: *const @This(), attrib: Attrib) void {
    for (0..self.h) |y|
        for (0..self.w) |x| {
            self.out[x + y * self.w] = .{ .char = ' ', .attrib = attrib };
        };
}

pub fn box(
    self: *const @This(),
    x: usize,
    y: usize,
    w: usize,
    h: usize,
    attrib: Attrib,
) void {
    self.putch(x, y, attrib, 0xda);
    self.putch(x + w, y, attrib, 0xbf);
    self.putch(x, y + h, attrib, 0xc0);
    self.putch(x + w, y + h, attrib, 0xd9);

    for (1..w) |i| {
        self.putch(x + i, y, attrib, 0xc4);
        self.putch(x + i, y + h, attrib, 0xc4);
    }
    for (1..h) |i| {
        self.putch(x, y + i, attrib, 0xb3);
        self.putch(x + w, y + i, attrib, 0xb3);
    }
}

pub fn print(
    self: *@This(),
    x: usize,
    y: usize,
    attrib: Attrib,
    comptime fmt: []const u8,
    args: anytype,
) void {
    const str = std.fmt.bufPrint(&self.buf, fmt, args) catch "";
    self.puts(x, y, attrib, str);
}

pub fn puts(
    self: *const @This(),
    x: usize,
    y: usize,
    attrib: Attrib,
    str: []const u8,
) void {
    for (str, 0..) |ch, i|
        self.putch(x + i, y, attrib, ch);
}

pub inline fn putch(
    self: *const @This(),
    x: usize,
    y: usize,
    attrib: Attrib,
    ch: u8,
) void {
    if (x >= self.w) return;
    if (y >= self.h) return;
    self.out[x + y * self.w] = Cell{ .char = ch, .attrib = attrib };
}
