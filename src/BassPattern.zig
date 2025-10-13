const std = @import("std");

pub const Size = std.math.IntFittingRange(1, maxlen);

pub const maxlen = 16;

pub const off: u4 = 0xf;

len: Size = 16,
base: u7 = 48,
steps: [maxlen]Step = [1]Step{.{}} ** maxlen,

pub inline fn length(self: *const @This()) Size {
    return @atomicLoad(Size, &self.len, .seq_cst);
}

pub fn incLength(self: *@This()) void {
    const len = @atomicLoad(Size, &self.len, .seq_cst);
    const new = @min(maxlen, len + 1);
    @atomicStore(Size, &self.len, new, .seq_cst);
}

pub fn decLength(self: *@This()) void {
    const len = @atomicLoad(Size, &self.len, .seq_cst);
    const new: Size = if (len <= 1) 1 else len - 1;
    @atomicStore(Size, &self.len, new, .seq_cst);
}

pub fn incBase(self: *@This()) void {
    const old = @atomicLoad(u7, &self.base, .seq_cst);
    if (old < 103) @atomicStore(u7, &self.base, old + 1, .seq_cst);
}

pub fn decBase(self: *@This()) void {
    const old = @atomicLoad(u7, &self.base, .seq_cst);
    if (old > 12) @atomicStore(u7, &self.base, old - 1, .seq_cst);
}

pub inline fn getBase(self: *@This()) u7 {
    return @atomicLoad(u7, &self.base, .seq_cst);
}

pub const Step = packed struct(u8) {
    pitch: u4 = off,
    octup: bool = false,
    octdown: bool = false,
    slide: bool = false,
    accent: bool = false,

    pub inline fn assume(self: *Step, new: Step) void {
        @atomicStore(Step, self, new, .seq_cst);
    }

    pub inline fn copy(self: *const Step) Step {
        return @atomicLoad(Step, self, .seq_cst);
    }

    pub inline fn active(self: *const Step) bool {
        const s = self.copy();
        return s.pitch != off;
    }

    pub inline fn delete(self: *Step) void {
        self.assume(.{});
    }

    pub fn midi(self: Step, base: u7) ?u7 {
        if (self.pitch == off) return null;
        var result = base;
        result +|= self.pitch;
        if (self.octup) result +|= 12;
        if (self.octdown) result -|= 12;
        return result;
    }
};
