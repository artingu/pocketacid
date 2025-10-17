const PDBass = @import("PDBass.zig");
const std = @import("std");

pub const JoyMode = enum {
    timbre_mod,
    res_feedback,
    decay_accent,

    pub const Pair = struct {
        x: u8,
        y: u8,
    };

    pub fn next(self: *JoyMode) void {
        self.* = switch (self.*) {
            .timbre_mod => .res_feedback,
            .res_feedback => .decay_accent,
            .decay_accent => .timbre_mod,
        };
    }

    pub fn fromShort(short: []const u8) !JoyMode {
        if (std.mem.eql(u8, short, "tm"))
            return .timbre_mod;
        if (std.mem.eql(u8, short, "rf"))
            return .res_feedback;
        if (std.mem.eql(u8, short, "da"))
            return .decay_accent;
        return error.BadJoyModeStr;
    }

    pub fn toShort(self: JoyMode) []const u8 {
        return switch (self) {
            .timbre_mod => "tm",
            .res_feedback => "rf",
            .decay_accent => "da",
        };
    }

    pub fn str(self: JoyMode) []const u8 {
        return switch (self) {
            .timbre_mod => "t/m",
            .res_feedback => "r/f",
            .decay_accent => "d/a",
        };
    }

    pub fn values(self: JoyMode, params: *const PDBass.Params) Pair {
        const FloatPair = struct { x: f32, y: f32 };
        const v: FloatPair = switch (self) {
            .timbre_mod => .{
                .y = params.get(.timbre),
                .x = params.get(.mod_depth),
            },
            .res_feedback => .{
                .y = params.get(.res),
                .x = params.get(.feedback),
            },
            .decay_accent => .{
                .y = params.get(.decay),
                .x = params.get(.accentness),
            },
        };

        return .{
            .x = @intFromFloat(@round(v.x * 0xff)),
            .y = @intFromFloat(@round(v.y * 0xff)),
        };
    }
};
