const PDBass = @import("PDBass.zig");
const DrumMachine = @import("DrumMachine.zig");
const SoundEngine = @import("SoundEngine.zig");
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const Mixer = @import("Mixer.zig");

engine: SoundEngine.Params = .{},
bass1: PDBass.Params = .{},
bass2: PDBass.Params = .{},
drums: DrumMachine.Params = .{},
delay: StereoFeedbackDelay.Params = .{},
mixer: [Mixer.nchannels]Mixer.Channel.Params = [1]Mixer.Channel.Params{.{}} ** Mixer.nchannels,
