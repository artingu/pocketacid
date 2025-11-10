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

delay: f32,
rate: f32,

held: f32 = 0,
state: enum {
    initial,
    repeat,
} = .initial,

pub fn trigger(self: *@This(), held: bool, dt: f32) bool {
    if (!held) {
        self.held = 0;
        self.state = .initial;
        return false;
    }

    defer self.held += dt;
    switch (self.state) {
        .initial => {
            if (self.held + dt > self.delay) {
                self.state = .repeat;
                self.held = self.rate;
            }
            if (self.held == 0)
                return true;
        },
        .repeat => {
            if (self.held >= self.rate) {
                self.held -= self.rate;
                return true;
            }
        },
    }
    return false;
}
