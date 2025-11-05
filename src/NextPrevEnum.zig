const std = @import("std");

pub fn NextPrevEnum(comptime E: type) type {
    return struct {
        pub fn prev(self: *E) void {
            switch (self.*) {
                inline else => |v| {
                    const values = comptime std.enums.values(E);
                    const idx = comptime std.mem.indexOfScalar(E, values, v) orelse @compileError("bad enum value");
                    const new_idx: usize = if (idx == 0) 0 else idx - 1;

                    self.* = values[new_idx];
                },
            }
        }

        pub fn next(self: *E) void {
            switch (self.*) {
                inline else => |v| {
                    const values = comptime std.enums.values(E);
                    const idx = comptime std.mem.indexOfScalar(E, values, v) orelse @compileError("bad enum value");
                    const new_idx: usize = if (idx == values.len - 1) 0 else idx + 1;

                    self.* = values[new_idx];
                },
            }
        }
    };
}
