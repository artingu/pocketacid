const std = @import("std");

pub const Size = std.math.IntFittingRange(1, maxlen);

pub const maxlen = 16;

pub const off: u4 = 0xf;

len: Size = 16,
steps: [maxlen]Step = [1]Step{.{}} ** maxlen,

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

    pub inline fn any(self: *const Step) bool {
        return self.copy() != Step{};
    }
};

pub inline fn length(self: *const @This()) Size {
    return @atomicLoad(Size, &self.len, .seq_cst);
}
