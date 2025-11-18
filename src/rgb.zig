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

const pi = @import("std").math.pi;
const sdl = @import("sdl.zig");
pub const RGB = packed struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    pub fn init(r: u8, g: u8, b: u8) @This() {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn initFloat(r: f32, g: f32, b: f32) @This() {
        return .{
            .r = @as(u8, @intFromFloat(@max(@min(r, 1), 0) * 255)),
            .g = @as(u8, @intFromFloat(@max(@min(g, 1), 0) * 255)),
            .b = @as(u8, @intFromFloat(@max(@min(b, 1), 0) * 255)),
        };
    }

    pub fn multiply(self: @This(), m: f32) @This() {
        return @This().initFloat(
            @as(f32, @floatFromInt(self.r)) * m / 255,
            @as(f32, @floatFromInt(self.g)) * m / 255,
            @as(f32, @floatFromInt(self.b)) * m / 255,
        );
    }

    pub fn rainbow(phase: f32) @This() {
        const f = 2.0 * pi;
        return .{
            .r = @intFromFloat(128.0 + 127.0 * @sin(f * phase)),
            .g = @intFromFloat(128.0 + 127.0 * @sin(f * ((1.0 / 3.0) + phase))),
            .b = @intFromFloat(128.0 + 127.0 * @sin(f * ((2.0 / 3.0) + phase))),
        };
    }

    pub fn interpolate(self: @This(), other: @This(), alpha: f32) @This() {
        const sa = 1 - alpha;
        const oa = alpha;

        const r = @as(f32, @floatFromInt(self.r)) * sa + @as(f32, @floatFromInt(other.r)) * oa;
        const g = @as(f32, @floatFromInt(self.g)) * sa + @as(f32, @floatFromInt(other.g)) * oa;
        const b = @as(f32, @floatFromInt(self.b)) * sa + @as(f32, @floatFromInt(other.b)) * oa;

        return .{
            .r = @intFromFloat(@min(0xff, @max(0, @round(r)))),
            .g = @intFromFloat(@min(0xff, @max(0, @round(g)))),
            .b = @intFromFloat(@min(0xff, @max(0, @round(b)))),
        };
    }

    pub fn brighten(self: @This(), factor: f32) @This() {
        return .{
            .r = brightened(self.r, factor),
            .g = brightened(self.g, factor),
            .b = brightened(self.b, factor),
        };
    }

    pub fn add(self: @This(), other: @This()) @This() {
        return .{
            .r = cadd(self.r, other.r),
            .g = cadd(self.g, other.g),
            .b = cadd(self.b, other.b),
        };
    }

    pub fn apply(self: @This(), r: *sdl.Renderer) void {
        _ = sdl.setRenderDrawColor(r, self.r, self.g, self.b, 0xff);
    }

    fn cadd(a: u8, b: u8) u8 {
        const sum = @as(usize, @intCast(a)) + @as(usize, @intCast(b));
        if (sum > 255) return 255;
        return @intCast(sum);
    }

    fn brightened(v: u8, factor: f32) u8 {
        const b = @as(f32, @floatFromInt(v)) * factor;
        if (b < 0) return 0;
        if (b > 255) return 255;
        return @intFromFloat(b);
    }
};
