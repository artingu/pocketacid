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

pub fn NextPrevEnum(comptime E: type, comptime wrap: bool) type {
    return struct {
        pub fn prev(self: *E) void {
            switch (self.*) {
                inline else => |v| {
                    const values = comptime std.enums.values(E);
                    const idx = comptime std.mem.indexOfScalar(E, values, v) orelse @compileError("bad enum value");
                    const minidx: usize = if (wrap) values.len - 1 else 0;
                    const new_idx: usize = if (idx == 0) minidx else idx - 1;

                    self.* = values[new_idx];
                },
            }
        }

        pub fn next(self: *E) void {
            switch (self.*) {
                inline else => |v| {
                    const values = comptime std.enums.values(E);
                    const idx = comptime std.mem.indexOfScalar(E, values, v) orelse @compileError("bad enum value");
                    const minidx: usize = if (wrap) 0 else idx;
                    const new_idx: usize = if (idx == values.len - 1) minidx else idx + 1;

                    self.* = values[new_idx];
                },
            }
        }
    };
}
