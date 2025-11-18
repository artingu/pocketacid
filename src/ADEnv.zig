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

const Accessor = @import("Accessor.zig").Accessor;

const State = enum { attack, decay };

const ADEnv = @This();
last_gate: bool = false,
charge: f32 = 0,
state: State = .attack,

pub const Params = struct {
    attack: f32 = 0,
    decay: f32 = 0.1,
    attack_shape: f32 = 0,
    decay_shape: f32 = 0,

    pub usingnamespace Accessor(@This());
};

pub fn trigger(self: *ADEnv) void {
    self.state = .attack;
    self.charge = 0;
}

pub fn next(self: *ADEnv, params: *const Params, srate: f32) f32 {
    const ap = params.get(.attack);
    const dp = params.get(.decay);
    const attack = ap * ap * 5;
    const decay = dp * dp * 5;

    switch (self.state) {
        .attack => {
            self.charge = if (attack != 0)
                self.charge + (1 / srate) / attack
            else
                1;
            if (self.charge >= 1) {
                self.state = .decay;
                self.charge = 1;
            }
        },
        .decay => self.charge = if (decay != 0)
            @max(0, self.charge - (1 / srate) / decay)
        else
            0,
    }

    const a: f32 = self.charge * self.charge;
    const b: f32 = 1 - (1 - self.charge) * (1 - self.charge);

    const shape_param = switch (self.state) {
        .attack => params.get(.attack_shape),
        .decay => params.get(.decay_shape),
    };

    return lerp(a, b, shape_param);
}

inline fn lerp(a: f32, b: f32, mix: f32) f32 {
    return a * (1 - mix) + b * mix;
}
