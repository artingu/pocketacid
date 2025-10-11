const DrumPattern = @import("DrumPattern.zig");
const BassPattern = @import("BassPattern.zig");

pub var bass_patterns: [256]BassPattern = [1]BassPattern{.{}} ** 256;
