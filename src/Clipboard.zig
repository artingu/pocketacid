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

const BassPattern = @import("BassPattern.zig");
const DrumPattern = @import("DrumPattern.zig");
const Arranger = @import("Arranger.zig");

const song = @import("song.zig");

const Buffer = union(enum) {
    none,
    bass: BassPattern,
    drum: DrumPattern,
};

buffer: Buffer = .none,

pub fn new(arr: *const Arranger) void {
    switch (arr.column) {
        0, 1 => if (song.findEmptyUnusedBassPattern()) |dst_pat| {
            const default = BassPattern{};
            song.bass_patterns[dst_pat].assume(&default);
            @atomicStore(u8, &arr.columns[arr.column][arr.row], dst_pat, .seq_cst);
        },
        2 => if (song.findEmptyUnusedDrumPattern()) |dst_pat| {
            const default = DrumPattern{};
            song.drum_patterns[dst_pat].assume(&default);
            @atomicStore(u8, &arr.columns[arr.column][arr.row], dst_pat, .seq_cst);
        },
        else => unreachable,
    }
}

pub fn clone(arr: *const Arranger) void {
    const orig_pat = @atomicLoad(u8, &arr.columns[arr.column][arr.row], .seq_cst);

    if (orig_pat == 0xff) return;

    switch (arr.column) {
        0, 1 => if (song.findEmptyUnusedBassPattern()) |dst_pat| {
            const pat_copy = song.bass_patterns[orig_pat].copy();
            song.bass_patterns[dst_pat].assume(&pat_copy);
            @atomicStore(u8, &arr.columns[arr.column][arr.row], dst_pat, .seq_cst);
        },
        2 => if (song.findEmptyUnusedDrumPattern()) |dst_pat| {
            const pat_copy = song.drum_patterns[orig_pat].copy();
            song.drum_patterns[dst_pat].assume(&pat_copy);
            @atomicStore(u8, &arr.columns[arr.column][arr.row], dst_pat, .seq_cst);
        },
        else => unreachable,
    }
}

pub fn copy(self: *@This(), arr: *const Arranger) void {
    const pat = arr.selectedPattern() orelse return;

    switch (arr.column) {
        0, 1 => {
            self.buffer = .{ .bass = song.bass_patterns[pat].copy() };
        },
        2 => {
            self.buffer = .{ .drum = song.drum_patterns[pat].copy() };
        },
        else => unreachable,
    }
}

pub fn paste(self: *@This(), arr: *const Arranger) void {
    const pat = arr.selectedPattern() orelse return;

    switch (arr.column) {
        0, 1 => switch (self.buffer) {
            .none => {},
            .bass => |*v| song.bass_patterns[pat].assume(v),
            .drum => {},
        },
        2 => switch (self.buffer) {
            .none => {},
            .bass => {},
            .drum => |*v| song.drum_patterns[pat].assume(v),
        },
        else => unreachable,
    }
}
