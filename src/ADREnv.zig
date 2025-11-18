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

const ADREnv = @This();

pub const Params = struct {
    attack: f32 = 0.01,
    decay: f32 = 0.3,
    release: f32 = 0.03,
};

stage: enum {
    release,
    attack,
    decay,
} = .release,
current: f32 = 0.0,
last_gate: bool = false,

pub fn next(self: *ADREnv, par: *const Params, gate: bool, srate: f32) f32 {
    const out: f32 = self.current;

    if (gate and !self.last_gate) {
        self.stage = .attack;
    } else if (!gate) {
        self.stage = .release;
    }
    self.last_gate = gate;

    self.current = switch (self.stage) {
        .release => @max(self.current - 1.0 / (par.release * srate), 0.0),
        .attack => @min(self.current + 1.0 / (par.attack * srate), 1.0),
        .decay => @max(self.current - 1.0 / (par.decay * srate), 0.0),
    };
    if (self.stage == .attack and self.current >= 1.0) self.stage = .decay;
    return switch (self.stage) {
        .decay, .release => out * out,
        .attack => out,
    };
}
