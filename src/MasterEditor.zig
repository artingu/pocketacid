const colors = @import("colors.zig");
const std = @import("std");

const TextMatrix = @import("TextMatrix.zig");
const InputState = @import("ButtonHandler.zig").States;
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const Attrib = @import("CharDisplay.zig").Attrib;
const Kit = @import("Kit.zig");

pub const Entry = union(enum) {
    u8: U8Entry,
    Kit: EnumEntry(Kit.Id),

    fn up(self: Entry) void {
        switch (self) {
            inline else => |e| e.up(),
        }
    }
    fn down(self: Entry) void {
        switch (self) {
            inline else => |e| e.down(),
        }
    }
    fn left(self: Entry) void {
        switch (self) {
            inline else => |e| e.left(),
        }
    }
    fn right(self: Entry) void {
        switch (self) {
            inline else => |e| e.right(),
        }
    }

    fn display(self: Entry, tm: *TextMatrix, x: usize, y: usize, color: Attrib) void {
        switch (self) {
            inline else => |e| e.display(tm, x, y, color),
        }
    }
};

pub const U8Entry = struct {
    label: []const u8,
    ptr: *u8,

    inline fn up(self: U8Entry) void {
        self.inc(0x10);
    }
    inline fn down(self: U8Entry) void {
        self.dec(0x10);
    }
    inline fn left(self: U8Entry) void {
        self.dec(1);
    }
    inline fn right(self: U8Entry) void {
        self.inc(1);
    }

    fn display(self: U8Entry, tm: *TextMatrix, x: usize, y: usize, color: Attrib) void {
        const value = @atomicLoad(u8, self.ptr, .seq_cst);
        tm.print(x, y, color, "{s} {x:0>2}", .{ self.label, value });
    }

    fn inc(self: U8Entry, by: u8) void {
        const prev = @atomicLoad(u8, self.ptr, .seq_cst);
        _ = @cmpxchgStrong(u8, self.ptr, prev, prev +| by, .seq_cst, .seq_cst);
    }

    fn dec(self: U8Entry, by: u8) void {
        const prev = @atomicLoad(u8, self.ptr, .seq_cst);
        _ = @cmpxchgStrong(u8, self.ptr, prev, prev -| by, .seq_cst, .seq_cst);
    }
};

menu: []const Entry,

idx: u8 = 0,
blink: f32 = 0,

pub fn display(self: *@This(), tm: *TextMatrix, x: usize, y: usize, dt: f32, active: bool) void {
    const on = @mod(self.blink * 4, 1) < 0.5;
    for (self.menu, 0..) |entry, i| {
        const color = if (!active)
            colors.inactive
        else if (i == self.idx)
            invertIf(colors.hilight, on)
        else
            colors.normal;

        entry.display(tm, x, y + i, color);
    }
    self.blink = @mod(self.blink + dt, 1);
}

pub fn handle(self: *@This(), input: InputState, active: bool) void {
    if (!active) return;
    if (input.hold.any()) self.blink = 0;

    const entry = self.menu[self.idx];
    if (input.hold.a) {
        if (input.repeat.up) entry.up();
        if (input.repeat.down) entry.down();
        if (input.repeat.left) entry.left();
        if (input.repeat.right) entry.right();
        return;
    }

    if (input.repeat.up) self.idx -|= 1;
    if (input.repeat.down) self.idx = @min(self.menu.len - 1, self.idx + 1);
}

fn invertIf(a: Attrib, condition: bool) Attrib {
    return if (condition)
        a.invert()
    else
        a;
}

pub fn EnumEntry(comptime E: type) type {
    return struct {
        label: []const u8,
        ptr: *E,

        fn up(self: @This()) void {
            _ = self;
        }
        fn down(self: @This()) void {
            _ = self;
        }

        fn display(self: @This(), tm: *TextMatrix, x: usize, y: usize, color: Attrib) void {
            const value = @atomicLoad(E, self.ptr, .seq_cst);
            tm.print(x, y, color, "{s} {s}", .{ self.label, @tagName(value) });
        }

        fn left(self: @This()) void {
            const current = @atomicLoad(E, self.ptr, .seq_cst);
            switch (current) {
                inline else => |v| {
                    const values = comptime std.enums.values(E);
                    const idx = comptime std.mem.indexOfScalar(E, values, v) orelse @compileError("bad EnumEntry enum value");
                    const new_idx: usize = if (idx == 0) 0 else idx - 1;

                    _ = @cmpxchgStrong(E, self.ptr, current, values[new_idx], .seq_cst, .seq_cst);
                },
            }
        }

        fn right(self: @This()) void {
            const current = @atomicLoad(E, self.ptr, .seq_cst);
            switch (current) {
                inline else => |v| {
                    const values = comptime std.enums.values(E);
                    const idx = comptime std.mem.indexOfScalar(E, values, v) orelse @compileError("bad EnumEntry enum value");
                    const new_idx: usize = if (idx == values.len - 1) values.len - 1 else idx + 1;

                    _ = @cmpxchgStrong(E, self.ptr, current, values[new_idx], .seq_cst, .seq_cst);
                },
            }
        }
    };
}
