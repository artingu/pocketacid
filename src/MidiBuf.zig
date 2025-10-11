const midi = @import("midi.zig");

buf: []midi.Event,
len: usize = 0,

pub inline fn feed(self: *@This(), e: midi.Event) void {
    if (self.len >= self.buf.len) return;

    self.buf[self.len] = e;
    self.len += 1;
}

pub fn emit(self: *@This()) []midi.Event {
    defer self.len = 0;
    return self.buf[0..self.len];
}
