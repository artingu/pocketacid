const std = @import("std");
const sdl = @import("sdl.zig");

pub const ButtonState = packed struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    a: bool = false,
    b: bool = false,
    x: bool = false,
    y: bool = false,
    l: bool = false,
    r: bool = false,
    start: bool = false,

    pub const Enum = enum {
        up,
        down,
        left,
        right,
        a,
        b,
        x,
        y,
        l,
        r,
        start,
        pub fn fromString(str: []const u8) ?Enum {
            return std.meta.stringToEnum(Enum, str);
        }
    };

    pub fn any(self: @This()) bool {
        return self != ButtonState{};
    }

    pub fn get(self: *const @This(), e: Enum) bool {
        return switch (e) {
            .up => self.up,
            .down => self.down,
            .left => self.left,
            .right => self.right,
            .a => self.a,
            .b => self.b,
            .x => self.x,
            .y => self.y,
            .l => self.l,
            .r => self.r,
            .start => self.start,
        };
    }

    pub fn set(self: *@This(), e: Enum, val: bool) void {
        switch (e) {
            .up => self.up = val,
            .down => self.down = val,
            .left => self.left = val,
            .right => self.right = val,
            .a => self.a = val,
            .b => self.b = val,
            .x => self.x = val,
            .y => self.y = val,
            .l => self.l = val,
            .r => self.r = val,
            .start => self.start = val,
        }
    }

    pub fn handle(self: *@This(), e: *sdl.Event) bool {
        switch (e.type) {
            sdl.KEYDOWN => {
                if (e.key.repeat != 0) return false;
                switch (e.key.keysym.scancode) {
                    sdl.SCANCODE_UP => self.up = true,
                    sdl.SCANCODE_DOWN => self.down = true,
                    sdl.SCANCODE_LEFT => self.left = true,
                    sdl.SCANCODE_RIGHT => self.right = true,
                    sdl.SCANCODE_Z => self.a = true,
                    sdl.SCANCODE_X => self.b = true,
                    sdl.SCANCODE_A => self.x = true,
                    sdl.SCANCODE_S => self.y = true,
                    sdl.SCANCODE_Q => self.l = true,
                    sdl.SCANCODE_W => self.r = true,
                    sdl.SCANCODE_RETURN => self.start = true,
                    else => return false,
                }
            },
            sdl.KEYUP => {
                if (e.key.repeat != 0) return false;
                switch (e.key.keysym.scancode) {
                    sdl.SCANCODE_UP => self.up = false,
                    sdl.SCANCODE_DOWN => self.down = false,
                    sdl.SCANCODE_LEFT => self.left = false,
                    sdl.SCANCODE_RIGHT => self.right = false,
                    sdl.SCANCODE_Z => self.a = false,
                    sdl.SCANCODE_X => self.b = false,
                    sdl.SCANCODE_A => self.x = false,
                    sdl.SCANCODE_S => self.y = false,
                    sdl.SCANCODE_Q => self.l = false,
                    sdl.SCANCODE_W => self.r = false,
                    sdl.SCANCODE_RETURN => self.start = false,
                    else => return false,
                }
            },
            sdl.CONTROLLERBUTTONUP => switch (e.cbutton.button) {
                sdl.CONTROLLER_BUTTON_DPAD_UP => self.up = false,
                sdl.CONTROLLER_BUTTON_DPAD_DOWN => self.down = false,
                sdl.CONTROLLER_BUTTON_DPAD_LEFT => self.left = false,
                sdl.CONTROLLER_BUTTON_DPAD_RIGHT => self.right = false,
                sdl.CONTROLLER_BUTTON_A => self.a = false,
                sdl.CONTROLLER_BUTTON_B => self.b = false,
                sdl.CONTROLLER_BUTTON_X => self.x = false,
                sdl.CONTROLLER_BUTTON_Y => self.y = false,
                sdl.CONTROLLER_BUTTON_LEFTSHOULDER => self.l = false,
                sdl.CONTROLLER_BUTTON_RIGHTSHOULDER => self.r = false,
                sdl.CONTROLLER_BUTTON_START => self.start = false,
                else => return false,
            },
            sdl.CONTROLLERBUTTONDOWN => switch (e.cbutton.button) {
                sdl.CONTROLLER_BUTTON_DPAD_UP => self.up = true,
                sdl.CONTROLLER_BUTTON_DPAD_DOWN => self.down = true,
                sdl.CONTROLLER_BUTTON_DPAD_LEFT => self.left = true,
                sdl.CONTROLLER_BUTTON_DPAD_RIGHT => self.right = true,
                sdl.CONTROLLER_BUTTON_A => self.a = true,
                sdl.CONTROLLER_BUTTON_B => self.b = true,
                sdl.CONTROLLER_BUTTON_X => self.x = true,
                sdl.CONTROLLER_BUTTON_Y => self.y = true,
                sdl.CONTROLLER_BUTTON_LEFTSHOULDER => self.l = true,
                sdl.CONTROLLER_BUTTON_RIGHTSHOULDER => self.r = true,
                sdl.CONTROLLER_BUTTON_START => self.start = true,
                else => return false,
            },
            else => return false,
        }
        return true;
    }
};

const Repeater = @import("Repeater.zig");
const delay: f32 = 0.2;
const rate: f32 = 0.05;

const Press = struct {
    held: bool = false,

    pub fn trigger(self: *@This(), held: bool, dt: f32) bool {
        _ = dt;
        defer self.held = held;
        if (held and !self.held)
            return true;
        return false;
    }
};

const Release = struct {
    held: bool = false,

    pub fn trigger(self: *@This(), held: bool, dt: f32) bool {
        _ = dt;
        defer self.held = held;
        if (!held and self.held)
            return true;
        return false;
    }
};

const Both = struct {
    repeat: Repeater = .{ .delay = delay, .rate = rate },
    press: Press = .{},
    release: Release = .{},
};

up: Both = .{},
down: Both = .{},
left: Both = .{},
right: Both = .{},
a: Both = .{},
b: Both = .{},
x: Both = .{},
y: Both = .{},
l: Both = .{},
r: Both = .{},
start: Both = .{},

pub const States = struct {
    hold: ButtonState = .{},
    repeat: ButtonState = .{},
    press: ButtonState = .{},
    release: ButtonState = .{},

    pub fn combo(self: *const @This(), comptime comb: []const u8) bool {
        return self.internalCombo(comb, .repeat);
    }

    pub fn comboPress(self: *const @This(), comptime comb: []const u8) bool {
        return self.internalCombo(comb, .press);
    }

    fn internalCombo(self: *const @This(), comptime comb: []const u8, comptime kind: enum { press, repeat }) bool {
        const Iterator = std.mem.SplitIterator(u8, .scalar);

        const arr = comptime parse: {
            var iter = Iterator{ .buffer = comb, .index = 0, .delimiter = '+' };
            var len: usize = 0;
            while (iter.next()) |_| len += 1;

            if (len == 0) @compileError("must contain at least one button");

            var arr: [len]ButtonState.Enum = undefined;

            iter.reset();

            var idx: usize = 0;
            while (iter.next()) |token| {
                arr[idx] = ButtonState.Enum.fromString(token) orelse {
                    @compileError("bad button name: " ++ token);
                };
                idx += 1;
            }

            break :parse arr;
        };

        const last = arr[arr.len - 1];

        const hold = comptime hold_calc: {
            var h = ButtonState{};
            h.set(arr[arr.len - 1], true);
            for (arr[0 .. arr.len - 1]) |button| h.set(button, true);
            break :hold_calc h;
        };

        return switch (kind) {
            .press => self.hold == hold and self.press.get(last),
            .repeat => self.hold == hold and self.repeat.get(last),
        };
    }
};

pub fn handle(self: *@This(), s: ButtonState, dt: f32) States {
    var bs = States{};

    inline for (std.meta.fields(@This())) |f| {
        @field(bs.repeat, f.name) = @field(self, f.name).repeat.trigger(@field(s, f.name), dt);
        @field(bs.press, f.name) = @field(self, f.name).press.trigger(@field(s, f.name), dt);
        @field(bs.release, f.name) = @field(self, f.name).release.trigger(@field(s, f.name), dt);
        @field(bs.hold, f.name) = @field(s, f.name);
    }

    return bs;
}
