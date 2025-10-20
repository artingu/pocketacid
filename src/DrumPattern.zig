const std = @import("std");

pub const maxlen = 16;

pub const DrumStep = packed struct(u16) {
    bd: bool = false,
    sd: bool = false,
    ch: bool = false,
    oh: bool = false,
    lt: bool = false,
    ht: bool = false,
    cy: bool = false,
    xx: bool = false,
    yy: bool = false,
    accent: bool = false,

    _: u6 = 0,

    pub fn get(self: *const DrumStep, t: DrumType) bool {
        const copy = @atomicLoad(DrumStep, self, .seq_cst);
        return switch (t) {
            inline else => |v| @field(copy, @tagName(v)),
        };
    }

    pub fn set(self: *DrumStep, t: DrumType, value: bool) void {
        var copy = @atomicLoad(DrumStep, self, .seq_cst);
        switch (t) {
            inline else => |v| @field(copy, @tagName(v)) = value,
        }
        @atomicStore(DrumStep, self, copy, .seq_cst);
    }
};

pub const DrumType = enum {
    bd,
    sd,
    ch,
    oh,
    lt,
    ht,
    cy,
    xx,
    yy,
    accent,

    pub const types = [_]DrumType{
        .bd,
        .sd,
        .ch,
        .oh,
        .lt,
        .ht,
        .cy,
        .xx,
        .yy,
        .accent,
    };

    pub fn next(self: *DrumType) void {
        self.* = switch (self.*) {
            .bd => .sd,
            .sd => .ch,
            .ch => .oh,
            .oh => .lt,
            .lt => .ht,
            .ht => .cy,
            .cy => .xx,
            .xx => .yy,
            .yy => .bd,
        };
    }

    pub fn prev(self: *DrumType) void {
        self.* = switch (self.*) {
            .bd => .yy,
            .sd => .bd,
            .ch => .sd,
            .oh => .ch,
            .lt => .oh,
            .ht => .lt,
            .cy => .ht,
            .xx => .cy,
            .yy => .xx,
        };
    }
};

bd: [maxlen]DrumStep = [1]DrumStep{.{}} ** maxlen,
len: u8 = maxlen,

pub fn incLength(self: *@This()) void {
    const len = @atomicLoad(u8, &self.len, .seq_cst);
    const new = @min(maxlen, len + 1);
    @atomicStore(u8, &self.len, new, .seq_cst);
}

pub fn decLength(self: *@This()) void {
    const len = @atomicLoad(u8, &self.len, .seq_cst);
    const new: u8 = if (len <= 1) 1 else len - 1;
    @atomicStore(u8, &self.len, new, .seq_cst);
}

pub inline fn length(self: *const @This()) u8 {
    return @atomicLoad(u8, &self.len, .seq_cst);
}

test DrumStep {
    const t = std.testing;

    var x = DrumStep{};

    x.set(.sd, true);
    try t.expect(x.get(.sd));
    x.set(.sd, false);
    try t.expect(!x.get(.sd));
}
