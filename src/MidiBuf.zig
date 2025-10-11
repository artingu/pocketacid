buf: []u8,
len: usize = 0,

pub inline fn feedByte(self: *@This(), b: u8) void {
    if (self.len >= self.buf.len) return;

    self.buf[self.len] = b;
    self.len += 1;
}

pub fn feed(self: *@This(), data: []u8) void {
    for (data) |b| self.feedByte(b);
}

pub fn emit(self: *@This()) []u8 {
    defer self.len = 0;
    return self.buf[0..self.len];
}
