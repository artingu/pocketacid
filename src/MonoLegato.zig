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

const MonoVoiceManager = @import("MonoVoiceManager.zig");
const Smoother = @import("Smoother.zig");

const MonoLegato = @This();

time: f32,
smoother: Smoother = .{},
gate: bool = false,

pub fn next(self: *MonoLegato, in: MonoVoiceManager.State, srate: f32) MonoVoiceManager.State {
    defer self.gate = in.gate;
    if (in.gate and !self.gate) self.smoother.short(in.pitch);

    return .{
        .pitch = self.smoother.next(in.pitch, self.time, srate),
        .gate = in.gate,
        .velocity = in.velocity,
    };
}
