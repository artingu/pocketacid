const std = @import("std");
const Cell = @import("CharDisplay.zig").Cell;

w: usize,
h: usize,
out: []Cell,
buf: [100]u8 = undefined,

pub fn clear(self: *const @This(), attrib: u8) void {
    for (0..self.h) |y|
        for (0..self.w) |x| {
            self.out[x + y * self.w] = .{ .char = ' ', .attrib = attrib };
        };
}

pub fn box(
    self: *const @This(),
    x: usize,
    y: usize,
    w: usize,
    h: usize,
    attrib: u8,
) void {
    self.putch(x, y, attrib, 0xda);
    self.putch(x + w, y, attrib, 0xbf);
    self.putch(x, y + h, attrib, 0xc0);
    self.putch(x + w, y + h, attrib, 0xd9);

    for (1..w) |i| {
        self.putch(x + i, y, attrib, 0xc4);
        self.putch(x + i, y + h, attrib, 0xc4);
    }
    for (1..h) |i| {
        self.putch(x, y + i, attrib, 0xb3);
        self.putch(x + w, y + i, attrib, 0xb3);
    }
}

pub fn print(
    self: *@This(),
    x: usize,
    y: usize,
    attrib: u8,
    comptime fmt: []const u8,
    args: anytype,
) void {
    const str = std.fmt.bufPrint(&self.buf, fmt, args) catch "";
    self.puts(x, y, attrib, str);
}

pub fn puts(
    self: *const @This(),
    x: usize,
    y: usize,
    attrib: u8,
    str: []const u8,
) void {
    for (str, 0..) |ch, i|
        self.putch(x + i, y, attrib, ch);
}

pub inline fn putch(
    self: *const @This(),
    x: usize,
    y: usize,
    attrib: u8,
    ch: u8,
) void {
    if (x >= self.w) return;
    if (y >= self.h) return;
    self.out[x + y * self.w] = Cell{ .char = ch, .attrib = attrib };
}
