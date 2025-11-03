const std = @import("std");

const Kit = @This();

bd: []const u8,
sd: []const u8,
ch: []const u8,
oh: []const u8,
lt: []const u8,
ht: []const u8,
cy: []const u8,
xx: []const u8,
yy: []const u8,
choh: []const u8,

pub const n_notes = 10;

pub const Id = enum(u7) {
    R6,
    R9,

    pub fn resolve(self: Id) *const Kit {
        return switch (self) {
            .R6 => &R6,
            .R9 => &R9,
        };
    }

    pub fn str(self: Id) []const u8 {
        return @tagName(self);
    }
};

pub const R6 = Kit{
    .bd = @embedFile("assets/samples/bd606.raw"),
    .ch = @embedFile("assets/samples/ch606.raw"),
    .oh = @embedFile("assets/samples/oh606.raw"),
    .cy = @embedFile("assets/samples/cy606.raw"),
    .ht = @embedFile("assets/samples/hi606.raw"),
    .lt = @embedFile("assets/samples/lo606.raw"),
    .sd = @embedFile("assets/samples/sd606.raw"),
    .xx = &.{},
    .yy = &.{},
    .choh = @embedFile("assets/samples/choh606.raw"),
};

const oh909 = @embedFile("assets/samples/oh909.raw");
pub const R9 = Kit{
    .bd = @embedFile("assets/samples/bd909.raw"),
    .ch = @embedFile("assets/samples/ch909.raw"),
    .oh = oh909,
    .cy = @embedFile("assets/samples/cy909.raw"),
    .ht = @embedFile("assets/samples/hi909.raw"),
    .lt = @embedFile("assets/samples/lo909.raw"),
    .sd = @embedFile("assets/samples/sd909.raw"),
    .xx = @embedFile("assets/samples/rs909.raw"),
    .yy = @embedFile("assets/samples/cp909.raw"),
    .choh = oh909,
};
