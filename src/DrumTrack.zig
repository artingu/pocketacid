const TextMatrix = @import("TextMatrix.zig");

pub const Step = struct {
    gates: u4 = 0,
    velocity: u4 = 0xf,

    pub inline fn gat(self: *const Step) u4 {
        return @atomicLoad(u4, &self.gates, .seq_cst);
    }

    pub inline fn vel(self: *const Step) u4 {
        return @atomicLoad(u4, &self.velocity, .seq_cst);
    }

    pub inline fn incVelocity(self: *Step) void {
        const velocity = @atomicLoad(u4, &self.velocity, .seq_cst);
        if (velocity < 0xf) @atomicStore(u4, &self.velocity, velocity + 1, .seq_cst);
    }

    pub inline fn decVelocity(self: *Step) void {
        const velocity = @atomicLoad(u4, &self.velocity, .seq_cst);
        if (velocity > 1) @atomicStore(u4, &self.velocity, velocity - 1, .seq_cst);
    }

    pub inline fn incGates(self: *Step) void {
        const gates = @atomicLoad(u4, &self.gates, .seq_cst);
        if (gates < 0xf) @atomicStore(u4, &self.gates, gates + 1, .seq_cst);
    }

    pub inline fn decGates(self: *Step) void {
        const gates = @atomicLoad(u4, &self.gates, .seq_cst);
        if (gates > 1) @atomicStore(u4, &self.gates, gates - 1, .seq_cst);
    }

    pub inline fn copy(self: *const Step) Step {
        return .{
            .gates = @atomicLoad(u4, &self.gates, .seq_cst),
            .velocity = @atomicLoad(u4, &self.velocity, .seq_cst),
        };
    }

    pub inline fn delete(self: *Step) void {
        @atomicStore(u4, &self.gates, 0, .seq_cst);
    }

    pub inline fn active(self: *const Step) bool {
        return @atomicLoad(u4, &self.gates, .seq_cst) != 0;
    }

    pub inline fn assume(self: *Step, step: Step) void {
        @atomicStore(u4, &self.gates, step.gates, .seq_cst);
        @atomicStore(u4, &self.velocity, step.velocity, .seq_cst);
    }
};

steps: [16]Step = [1]Step{.{}} ** 16,
len: u8 = 16,
div: u8 = 16,

pub inline fn incLen(self: *@This()) void {
    const len = @atomicLoad(u8, &self.len, .seq_cst);
    const new = if (len < 16) len + 1 else 16;
    @atomicStore(u8, &self.len, new, .seq_cst);
}

pub inline fn decLen(self: *@This()) void {
    const len = @atomicLoad(u8, &self.len, .seq_cst);
    const new = if (len > 1) len - 1 else 1;
    @atomicStore(u8, &self.len, new, .seq_cst);
}

pub inline fn incDiv(self: *@This()) void {
    const div = @atomicLoad(u8, &self.div, .seq_cst);
    const new = if (div < 16) div + 1 else 16;
    @atomicStore(u8, &self.div, new, .seq_cst);
}

pub inline fn decDiv(self: *@This()) void {
    const div = @atomicLoad(u8, &self.div, .seq_cst);
    const new = if (div > 1) div - 1 else 1;
    @atomicStore(u8, &self.div, new, .seq_cst);
}
