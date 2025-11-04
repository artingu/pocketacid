const Params = @import("Params.zig");

enabled: bool = false,
params: Params = .{},

pub fn upload(self: *@This(), params: *const Params) void {
    @atomicStore(bool, &self.enabled, false, .seq_cst);
    self.params.assume(params);
    @atomicStore(bool, &self.enabled, true, .seq_cst);
}

pub fn delete(self: *@This()) void {
    @atomicStore(bool, &self.enabled, false, .seq_cst);
}

pub fn active(self: *const @This()) bool {
    return @atomicLoad(bool, &self.enabled, .seq_cst);
}
