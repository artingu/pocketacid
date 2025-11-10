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

const midi = @import("midi.zig");

buf: []midi.Event,
len: usize = 0,

pub inline fn feed(self: *@This(), e: midi.Event) void {
    if (self.len >= self.buf.len) return;

    self.buf[self.len] = e;
    self.len += 1;
}

pub fn emit(self: *@This()) []midi.Event {
    defer self.len = 0;
    return self.buf[0..self.len];
}
