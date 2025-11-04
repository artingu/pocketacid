const DrumPattern = @import("DrumPattern.zig");
const BassPattern = @import("BassPattern.zig");
const Snapshot = @import("Snapshot.zig");

pub var bass_patterns: [256]BassPattern = [1]BassPattern{.{}} ** 256;
pub var drum_patterns: [256]DrumPattern = [1]DrumPattern{.{}} ** 256;
pub var snapshots: [256]Snapshot = [1]Snapshot{.{}} ** 256;

pub var bass1_arrange: [256]u8 = [1]u8{0xff} ** 256;
pub var bass2_arrange: [256]u8 = [1]u8{0xff} ** 256;
pub var drum_arrange: [256]u8 = [1]u8{0xff} ** 256;
