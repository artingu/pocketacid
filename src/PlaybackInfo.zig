pub const PlaybackInfo = packed struct {
    arrangement_row: u8 = 0,
    pattern: u8 = 0,
    step: u8 = 0,
    running: bool = false,
    _: u7 = 0,
};
