const std = @import("std");

const DrumPattern = @import("DrumPattern.zig");
const PDBass = @import("PDBass.zig");
const DrumMachine = @import("DrumMachine.zig");
const BassPattern = @import("BassPattern.zig");
const Arranger = @import("Arranger.zig");
const MixerEditor = @import("MixerEditor.zig");
const Mixer = @import("Mixer.zig");
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const Ducker = @import("Ducker.zig");

var chunkbuf: [0xffff]u8 = undefined;

pub const ChunkTag = enum {
    // patterns
    BPAT,
    DPAT,

    // bass patches
    PTC1,
    PTC2,

    // arrangement columns
    ARR1,
    ARR2,
    ARR3,

    // Arranger state
    ARRS,

    // Tempo
    TMPO,

    // Joystick modes
    JOYM,

    // Mixer editor state
    MXED,

    // Mixer rows
    MXLV,
    MXPA,
    MXSE,
    MXDU,

    // Drum mutes
    DRMM,

    // Delay params
    DLPR,

    // Ducker params
    DUPR,

    // Master drive
    MADR,

    fn str(self: ChunkTag) [4]u8 {
        return switch (self) {
            inline else => |tag| @tagName(tag).*,
        };
    }
};

fn writeChunk(tag: ChunkTag, version: u16, data: []const u8, w: std.io.AnyWriter) !void {
    if (data.len > 0xffff) return error.TooBigChunk;

    try w.writeAll(&tag.str());
    try w.writeInt(u16, version, .little);
    try w.writeInt(u16, @intCast(data.len), .little);
    try w.writeAll(data);
}

const ChunkHandle = struct {
    tag: ChunkTag,
    version: u16,
    w: std.io.FixedBufferStream([]u8),

    fn finalize(self: *const ChunkHandle, w: std.io.AnyWriter) !void {
        try writeChunk(self.tag, self.version, self.w.buffer[0..self.w.pos], w);
    }
};

fn beginChunk(tag: ChunkTag, version: u16) ChunkHandle {
    return .{
        .tag = tag,
        .version = version,
        .w = .{ .buffer = &chunkbuf, .pos = 0 },
    };
}

pub fn load(
    r: std.io.AnyReader,
    ptc1: *PDBass.Params,
    ptc2: *PDBass.Params,
    arr1: *[256]u8,
    arr2: *[256]u8,
    arr3: *[256]u8,
    bpat: *[256]BassPattern,
    dpat: *[256]DrumPattern,
    arranger: *Arranger,
    tempo: *f32,
    mixer_editor: *MixerEditor,
    mixer: *Mixer,
    mutes: *DrumMachine.Mutes,
    delay: *StereoFeedbackDelay.Params,
    ducker: *Ducker.Params,
    master_drive: *u8,
) !void {
    chunkloop: while (true) {
        var tagnamebuf: [4]u8 = undefined;
        r.readNoEof(&tagnamebuf) catch |err| {
            if (err == error.EndOfStream)
                break :chunkloop
            else
                return err;
        };
        const tag = std.meta.stringToEnum(ChunkTag, &tagnamebuf) orelse return error.UnknownTag;
        const version = try r.readInt(u16, .little);
        const len = try r.readInt(u16, .little);

        switch (tag) {
            .ARRS => try readArrangerState(r, arranger, version, len),
            .BPAT => try readBassPatterns(r, bpat, version, len),
            .DPAT => try readDrumPatterns(r, dpat, version, len),
            .PTC1 => try readPatch(r, ptc1, version, len),
            .PTC2 => try readPatch(r, ptc2, version, len),
            .ARR1 => try readArr(r, arr1, version, len),
            .ARR2 => try readArr(r, arr2, version, len),
            .ARR3 => try readArr(r, arr3, version, len),
            .TMPO => try readTempo(r, tempo, version, len),
            .JOYM => try skipLoad(r, len),
            .MXED => try readMixerEditorState(r, mixer_editor, version, len),
            .MXLV => try readMixerLvls(r, mixer, version, len),
            .MXPA => try readMixerPans(r, mixer, version, len),
            .MXSE => try readMixerSends(r, mixer, version, len),
            .MXDU => try readMixerDuckings(r, mixer, version, len),
            .DRMM => try readDrumMutes(r, mutes, version, len),
            .DLPR => try readDelayParams(r, delay, version, len),
            .DUPR => try readDuckerParams(r, ducker, version, len),
            .MADR => try readMasterDrive(r, master_drive, version, len),
        }
    }
}

// Use for deprecated fields
fn skipLoad(r: std.io.AnyReader, len: usize) !void {
    try r.skipBytes(len, .{});
}

fn readMasterDrive(r: std.io.AnyReader, master_drive: *u8, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 1) return error.MasterDriveBadLen;
            @atomicStore(u8, master_drive, try r.readInt(u8, .little), .seq_cst);
        },
        else => return error.MasterDriveBadVersion,
    }
}

fn readDuckerParams(r: std.io.AnyReader, ducker: *Ducker.Params, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 1) return error.DuckerParamsBadLen;
            ducker.set(.time, try r.readInt(u8, .little));
        },
        else => return error.DuckerParamsBadVersion,
    }
}

fn readDelayParams(r: std.io.AnyReader, delay: *StereoFeedbackDelay.Params, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 2) return error.DelayParamsBadLen;
            delay.set(.time, try r.readInt(u8, .little));
            delay.set(.feedback, try r.readInt(u8, .little));
        },
        2 => {
            if (len != 3) return error.DelayParamsBadLen;
            delay.set(.time, try r.readInt(u8, .little));
            delay.set(.feedback, try r.readInt(u8, .little));
            delay.set(.duck, try r.readInt(u8, .little));
        },
        else => return error.DelayParamsBadVersion,
    }
}

fn readDrumMutes(r: std.io.AnyReader, mutes: *DrumMachine.Mutes, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 1) return error.DrumMutesBadLen;
            mutes.* = @bitCast(try r.readInt(u8, .little));
        },
        else => return error.DrumMutesBadVersion,
    }
}

fn readMixerLvls(r: std.io.AnyReader, mixer: *Mixer, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != Mixer.nchannels) return error.MixerLevelsBadLen;

            for (0..Mixer.nchannels) |i| {
                mixer.channels[i].level = try r.readInt(u8, .little);
            }
        },
        else => return error.MixerLevelsBadVersion,
    }
}

fn readMixerDuckings(r: std.io.AnyReader, mixer: *Mixer, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != Mixer.nchannels) return error.MixerDuckingsBadLen;

            for (0..Mixer.nchannels) |i| {
                mixer.channels[i].duck = try r.readInt(u8, .little);
            }
        },
        else => return error.MixerDuckingsBadVersion,
    }
}

fn readMixerSends(r: std.io.AnyReader, mixer: *Mixer, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != Mixer.nchannels) return error.MixerSendsBadLen;

            for (0..Mixer.nchannels) |i| {
                mixer.channels[i].send = try r.readInt(u8, .little);
            }
        },
        else => return error.MixerSendsBadVersion,
    }
}

fn readMixerPans(r: std.io.AnyReader, mixer: *Mixer, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != Mixer.nchannels) return error.MixerPansBadLen;

            for (0..Mixer.nchannels) |i| {
                mixer.channels[i].pan = try r.readInt(u8, .little);
            }
        },
        else => return error.MixerPansBadVersion,
    }
}

fn readMixerEditorState(r: std.io.AnyReader, mixer_editor: *MixerEditor, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 2) return error.MixerEditorStateBadLen;

            const channel = try r.readInt(u8, .little);
            if (channel >= Mixer.nchannels)
                return error.MixerEditorStateBadChannel;
            mixer_editor.selected_channel = channel;

            const row_ch = try r.readInt(u8, .little);
            switch (row_ch) {
                'l' => mixer_editor.selected_row = .lvl,
                'p' => mixer_editor.selected_row = .pan,
                's' => mixer_editor.selected_row = .snd,
                'd' => mixer_editor.selected_row = .dck,
                else => return error.MixerEditorStateBadRow,
            }
        },
        else => return error.MixerEditorStateBadVersion,
    }
}

fn readTempo(r: std.io.AnyReader, tempo: *f32, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 2) return error.TempoBadLen;
            const uint_tempo = try r.readInt(u16, .little);
            tempo.* = @floatFromInt(uint_tempo);
        },
        else => return error.TempoBadVersion,
    }
}

fn readArrangerState(r: std.io.AnyReader, arranger: *Arranger, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 2) return error.ArrangerStateBadLen;

            const column = try r.readInt(u8, .little);
            const row = try r.readInt(u8, .little);

            if (column >= 3) return error.ArrangerStateColumnOutOfRange;

            arranger.column = column;
            arranger.row = row;
        },
        else => return error.ArrangerStateBadVersion,
    }
}

fn readBassPatterns(r: std.io.AnyReader, patterns: *[256]BassPattern, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != (2 + BassPattern.maxlen) * 255) return error.BassPatternsBadLen;
            for (0..255) |i| {
                try readBassPattern(r, &patterns.*[i]);
            }
        },
        else => return error.BassPatternsBadVersion,
    }
}

fn readBassPattern(r: std.io.AnyReader, pattern: *BassPattern) !void {
    const len = try r.readInt(u8, .little);
    if (len > BassPattern.maxlen) return error.BassPatternLenNotInRange;
    pattern.len = len;

    const base = try r.readInt(u8, .little);
    if (base > 127) return error.BassPatternBaseNotInRange;
    pattern.base = @intCast(base);

    for (0..BassPattern.maxlen) |i| {
        pattern.steps[i] = @bitCast(try r.readInt(u8, .little));
    }
}

fn readDrumPatterns(r: std.io.AnyReader, patterns: *[256]DrumPattern, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != (1 + 2 * DrumPattern.maxlen) * 255) return error.DrumPatternsBadLen;
            for (0..255) |i| try readDrumPattern(r, &patterns.*[i]);
        },
        else => return error.DrumPatternsBadVersion,
    }
}

fn readDrumPattern(r: std.io.AnyReader, pattern: *DrumPattern) !void {
    const len = try r.readInt(u8, .little);
    if (len > DrumPattern.maxlen) return error.DrumPatternLenNotInRange;
    pattern.len = len;

    for (0..DrumPattern.maxlen) |i| {
        const step_int = try r.readInt(u16, .little);
        pattern.steps[i] = @bitCast(step_int);
    }
}

fn readPatch(r: std.io.AnyReader, params: *PDBass.Params, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 6 * 2) return error.BadPatchLen;
            params.set(.timbre, try readFloat01(r));
            params.set(.mod_depth, try readFloat01(r));
            params.set(.res, try readFloat01(r));
            params.set(.feedback, try readFloat01(r));
            params.set(.decay, try readFloat01(r));
            params.set(.accentness, try readFloat01(r));
        },
        else => return error.PatchBadVersion,
    }
}

fn readFloat01(r: std.io.AnyReader) !f32 {
    return @as(f32, @floatFromInt(try r.readInt(u16, .little))) / 0xffff;
}

fn readArr(r: std.io.AnyReader, arr: *[256]u8, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 256) return error.ArrBadLen;
            try r.readNoEof(arr);
        },
        else => return error.ArrUnknownVersion,
    }
}

pub fn save(
    w: std.io.AnyWriter,
    ptc1: *const PDBass.Params,
    ptc2: *const PDBass.Params,
    arr1: *const [256]u8,
    arr2: *const [256]u8,
    arr3: *const [256]u8,
    bpat: *const [256]BassPattern,
    dpat: *const [256]DrumPattern,
    arranger: *const Arranger,
    tempo: f32,
    mixer_editor: *const MixerEditor,
    mixer: *const Mixer,
    mutes: *const DrumMachine.Mutes,
    delay: *const StereoFeedbackDelay.Params,
    ducker: *const Ducker.Params,
    master_drive: u8,
) !void {
    try writeChunk(.ARR1, 1, arr1, w);
    try writeChunk(.ARR2, 1, arr2, w);
    try writeChunk(.ARR3, 1, arr3, w);

    var handle = beginChunk(.BPAT, 1);
    {
        const hw = handle.w.writer().any();
        for (0..255) |i| {
            const pat = &bpat.*[i];

            try hw.writeInt(u8, pat.length(), .little);
            try hw.writeInt(u8, pat.getBase(), .little);

            for (0..BassPattern.maxlen) |j| {
                try hw.writeInt(u8, @bitCast(pat.steps[j]), .little);
            }
        }
    }
    try handle.finalize(w);

    handle = beginChunk(.DPAT, 1);
    {
        const hw = handle.w.writer().any();
        for (0..255) |i| {
            const pat = &dpat.*[i];

            try hw.writeInt(u8, pat.length(), .little);

            for (0..DrumPattern.maxlen) |j| {
                const step_int: u16 = @bitCast(pat.steps[j]);
                try hw.writeInt(u16, step_int, .little);
            }
        }
    }
    try handle.finalize(w);

    handle = beginChunk(.PTC1, 1);
    try writeBassParams(handle.w.writer().any(), ptc1);
    try handle.finalize(w);

    handle = beginChunk(.PTC2, 1);
    try writeBassParams(handle.w.writer().any(), ptc2);
    try handle.finalize(w);

    handle = beginChunk(.ARRS, 1);
    {
        const hw = handle.w.writer().any();
        try hw.writeInt(u8, arranger.column, .little);
        try hw.writeInt(u8, arranger.row, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.TMPO, 1);
    {
        const hw = handle.w.writer().any();
        const int_tempo: u16 = @intFromFloat(@round(@min(65535, @max(0, tempo))));
        try hw.writeInt(u16, int_tempo, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.MXED, 1);
    {
        const hw = handle.w.writer().any();

        try hw.writeInt(u8, mixer_editor.selected_channel, .little);

        const row_ch: u8 = switch (mixer_editor.selected_row) {
            .lvl => 'l',
            .pan => 'p',
            .snd => 's',
            .dck => 'd',
        };
        try hw.writeInt(u8, row_ch, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.MXLV, 1);
    {
        const hw = handle.w.writer().any();

        for (0..Mixer.nchannels) |i| try hw.writeInt(u8, mixer.channels[i].level, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.MXPA, 1);
    {
        const hw = handle.w.writer().any();

        for (0..Mixer.nchannels) |i| try hw.writeInt(u8, mixer.channels[i].pan, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.MXSE, 1);
    {
        const hw = handle.w.writer().any();

        for (0..Mixer.nchannels) |i| try hw.writeInt(u8, mixer.channels[i].send, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.MXDU, 1);
    {
        const hw = handle.w.writer().any();

        for (0..Mixer.nchannels) |i| try hw.writeInt(u8, mixer.channels[i].duck, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.DLPR, 2);
    {
        const hw = handle.w.writer().any();

        try hw.writeInt(u8, delay.get(.time), .little);
        try hw.writeInt(u8, delay.get(.feedback), .little);
        try hw.writeInt(u8, delay.get(.duck), .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.DUPR, 1);
    {
        const hw = handle.w.writer().any();
        try hw.writeInt(u8, ducker.get(.time), .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.DRMM, 1);
    try handle.w.writer().any().writeInt(u8, @bitCast(mutes.*), .little);
    try handle.finalize(w);

    handle = beginChunk(.MADR, 1);
    try handle.w.writer().any().writeInt(u8, master_drive, .little);
    try handle.finalize(w);
}

fn writeBassParams(w: std.io.AnyWriter, params: *const PDBass.Params) !void {
    try writeParam01(w, params.get(.timbre));
    try writeParam01(w, params.get(.mod_depth));
    try writeParam01(w, params.get(.res));
    try writeParam01(w, params.get(.feedback));
    try writeParam01(w, params.get(.decay));
    try writeParam01(w, params.get(.accentness));
}

fn writeParam01(w: std.io.AnyWriter, val: f32) !void {
    const capped: f32 = 0xffff * @min(1, @max(0, val));
    const int: u16 = @intFromFloat(@round(capped));

    try w.writeInt(u16, int, .little);
}
