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

const FractionalDelayLine = @This();

delay: Delay,
allpass: Allpass = .{},

pub fn feed(self: *FractionalDelayLine, in: f32) void {
    self.delay.feed(in);
}

pub fn out(self: *FractionalDelayLine, delay: f32) f32 {
    return self.allpass.next(self.delay.out(delay), delay);
}

pub fn reset(self: *FractionalDelayLine) void {
    self.delay.reset();
    self.allpass.reset();
}

const Delay = struct {
    buffer: []f32,
    idx: usize = 0,

    fn feed(self: *Delay, in: f32) void {
        self.buffer[self.idx] = in;
        self.idx = (self.idx + 1) % self.buffer.len;
    }

    fn out(self: *const Delay, delay: f32) f32 {
        const integer_delay: usize = @min(@as(usize, @intFromFloat(@floor(delay))), self.buffer.len);
        const out_idx = (self.idx + self.buffer.len - integer_delay) % self.buffer.len;
        return self.buffer[out_idx];
    }

    fn reset(self: *Delay) void {
        self.* = .{ .buffer = self.buffer };
    }
};

const Allpass = struct {
    out: f32 = 0,
    in: f32 = 0,

    fn next(self: *Allpass, in: f32, delay: f32) f32 {
        const frac_delay = delay - @floor(delay);
        const coef = (1 - frac_delay) / (1 + frac_delay);
        self.out = coef * in + self.in - coef * self.out;
        self.in = in;
        return self.out;
    }

    fn reset(self: *Allpass) void {
        self.reset = 0;
    }
};
