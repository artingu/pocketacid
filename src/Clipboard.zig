const BassPattern = @import("BassPattern.zig");
const DrumPattern = @import("DrumPattern.zig");
const Arranger = @import("Arranger.zig");

const state = @import("state.zig");

const Buffer = union(enum) {
    none,
    bass: BassPattern,
    drum: DrumPattern,
};

buffer: Buffer = .none,

pub fn copy(self: *@This(), arr: *const Arranger) void {
    const pat = arr.selectedPattern() orelse return;

    switch (arr.column) {
        0, 1 => {
            self.buffer = .{ .bass = state.bass_patterns[pat].copy() };
        },
        2 => {
            self.buffer = .{ .drum = state.drum_patterns[pat].copy() };
        },
        else => unreachable,
    }
}

pub fn paste(self: *@This(), arr: *const Arranger) void {
    const pat = arr.selectedPattern() orelse return;

    switch (arr.column) {
        0, 1 => switch (self.buffer) {
            .none => {},
            .bass => |*v| state.bass_patterns[pat].assume(v),
            .drum => {},
        },
        2 => switch (self.buffer) {
            .none => {},
            .bass => {},
            .drum => |*v| state.drum_patterns[pat].assume(v),
        },
        else => unreachable,
    }
}
