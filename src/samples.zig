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

pub const Player = struct {
    index: usize = 0,
    sample: []const u8 = &.{},
    rate: f32 = 32000,
    phase: f32 = 0,
    volume: f32 = 1.0,

    pub fn next(self: *Player, srate: f32) f32 {
        if (self.index >= self.sample.len) {
            return 0;
        }
        while (self.phase >= 1) {
            self.phase -= 1;
            self.index += 2;
        }
        self.phase += self.rate / srate;
        if (self.index < self.sample.len) {
            const intsample: i16 = @as(i16, @intCast(self.sample[self.index])) | (@as(i16, @intCast(self.sample[self.index + 1])) << 8);
            const floatsample: f32 = @as(f32, @floatFromInt(intsample)) / 32768;

            return self.volume * floatsample;
        }
        return 0;
    }

    pub fn stop(self: *Player) void {
        self.index = self.sample.len;
    }

    pub fn trigger(self: *Player, sample: []const u8, volume: f32) void {
        self.volume = volume * volume;
        self.sample = sample;
        self.index = 0;
        self.phase = 0;
    }
};
