const std = @import("std");

pub const Size = std.math.IntFittingRange(1, maxlen);

pub const maxlen = 16;

pub const off: u4 = 0xf;

len: Size = 16,
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
};
