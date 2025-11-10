// Copyright (C) 2025  Philip Linde
//
// This file is part of corrode.
//
// corrode is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// corrode is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with corrode.  If not, see <https://www.gnu.org/licenses/>.

const Arranger = @This();

const Attrib = @import("CharDisplay.zig").Attrib;
const RGB = @import("rgb.zig").RGB;
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const InputState = @import("ButtonHandler.zig").States;
const TextMatrix = @import("TextMatrix.zig");
const Snapshot = @import("Snapshot.zig");
const Theme = @import("Theme.zig");
const Params = @import("Params.zig");

const height = 17;

columns: []const *[256]u8,
snapshots: *[256]Snapshot,
params: *Params,

upload_anim: ?UploadAnim = null,
column: u8 = 0,
row: u8 = 0,
blink: f32 = 0,
qblink: f32 = 0,
changed: bool = false,
yank: u8 = 0,

const UploadAnim = struct {
    row: u8,

    time: f32 = 1,

    fn attrib(self: *const UploadAnim, colors: *const Theme) Attrib {
        const t3 = self.time * self.time * self.time;
        const t = @min(1, @max(0, t3));
        const c = colors.hilight2.fg.interpolate(colors.playing.fg, t);
        return .{ .bg = colors.hilight2.bg, .fg = c };
    }
};

pub inline fn selectedPattern(self: *const Arranger) ?u8 {
    const over_addr = &self.columns[self.column].*[self.row];
    const curval = @atomicLoad(u8, over_addr, .seq_cst);
    if (curval == 0xff) return null;
    return curval;
}

pub fn rowEmpty(self: *const Arranger, row: u8) bool {
    for (self.columns) |column|
        if (column.*[row] != 0xff) return false;
    return true;
}

pub fn nextStart(self: *Arranger) void {
    var prev_empty = false;
    for (0..256) |i| {
        const cur: u8 = self.row +% @as(u8, @intCast(i));

        const cur_empty = self.rowEmpty(cur);

        if (!cur_empty and prev_empty) {
            self.row = cur;
            return;
        }

        prev_empty = cur_empty;
    }
}
pub fn prevStart(self: *Arranger) void {
    for (1..256) |i| {
        const cur: u8 = self.row -% @as(u8, @intCast(i));
        const prev: u8 = cur -% 1;

        if (self.rowEmpty(prev) and !self.rowEmpty(cur)) {
            self.row = cur;
            return;
        }
    }
}

pub fn handle(self: *Arranger, input: InputState) void {
    const over_addr = &self.columns[self.column].*[self.row];
    const curval = @atomicLoad(u8, over_addr, .seq_cst);
    if (input.hold.any()) self.blink = 0;

    if (input.hold.y) {
        if (input.press.up) {
            self.snapshots[self.row].upload(self.params);
            self.upload_anim = UploadAnim{ .row = self.row };
        }
        if (input.press.down and self.snapshots[self.row].active())
            self.params.assumeNoTempo(&self.snapshots[self.row].params);
        if (input.press.b) self.snapshots[self.row].delete();

        self.changed = false;
        return;
    }

    if (input.hold.b) {
        if (input.repeat.up) self.row -%= 16;
        if (input.repeat.down) self.row +%= 16;
        if (input.repeat.left) self.prevStart();
        if (input.repeat.right) self.nextStart();

        self.changed = false;
        return;
    }

    if (input.press.a) {
        if (curval == 0xff) {
            @atomicStore(u8, over_addr, self.yank, .seq_cst);
            self.changed = true;
        } else {
            self.changed = false;
        }
    }

    if (input.release.a) {
        if (!self.changed and curval != 0xff) {
            self.yank = curval;
            @atomicStore(u8, over_addr, 0xff, .seq_cst);
        }
    }

    if (input.combo("a+left") and curval != 0xff) {
        const newval = curval -| 1;
        @atomicStore(u8, over_addr, newval, .seq_cst);
        self.yank = newval;
        self.changed = true;
    }

    if (input.combo("a+right") and curval < 0xfe) {
        const newval = curval + 1;
        @atomicStore(u8, over_addr, newval, .seq_cst);
        self.yank = newval;
        self.changed = true;
    }

    if (input.combo("a+down") and curval != 0xff) {
        const newval = if (curval >= 0x10)
            curval - 0x10
        else
            0x00;
        @atomicStore(u8, over_addr, newval, .seq_cst);
        self.yank = newval;
        self.changed = true;
    }

    if ((input.combo("a+up")) and curval != 0xff) {
        const newval = if (curval < 0xef)
            curval + 0x10
        else
            0xfe;
        @atomicStore(u8, over_addr, newval, .seq_cst);
        self.yank = newval;
        self.changed = true;
    }

    if (input.combo("up")) self.prevRow();
    if (input.combo("down")) self.nextRow();

    if (input.combo("left")) self.prevColumn();
    if (input.combo("right")) self.nextColumn();
}

inline fn nextRow(self: *Arranger) void {
    self.row +%= 1;
}

inline fn prevRow(self: *Arranger) void {
    self.row -%= 1;
}

inline fn nextColumn(self: *Arranger) void {
    self.column = if (self.column == self.columns.len - 1)
        0
    else
        self.column + 1;
}

inline fn prevColumn(self: *Arranger) void {
    self.column = @intCast(if (self.column == 0)
        self.columns.len - 1
    else
        self.column - 1);
}

pub fn display(
    self: *Arranger,
    tm: *TextMatrix,
    x: usize,
    y: usize,
    dt: f32,
    active: bool,
    playback_info: []const PlaybackInfo,
    queued_info: []const ?u8,
    c: *const Theme,
) void {
    const half_height: isize = height / 2;
    const on = !active or @mod(self.blink * 4, 1) < 0.5;

    const faded = c.faded(0.5);
    const colors = if (active) c else &faded;

    for (0..height) |yoffset| {
        const idx: isize = @as(isize, @intCast(yoffset)) + self.row - half_height;

        if (idx >= 0 and idx < 256) {
            const uidx: u8 = @intCast(idx);
            tm.print(x, y + yoffset, colors.hilight2, "{x:0>2}", .{uidx});

            for (self.columns, 1..) |column, xoffset| {
                const val = @atomicLoad(u8, &column.*[uidx], .seq_cst);

                const row_queued = if (queued_info[xoffset - 1]) |row|
                    row == uidx
                else
                    false;
                const blink_queued = val != 0xff and row_queued and @mod(self.qblink * 4, 1) < 0.5;

                const alter = [_]Attrib{ colors.normal, colors.hilight };
                const pi = playback_info[xoffset - 1];

                const playing_row = pi.running and pi.arrangement_row == uidx;

                const bc = if (playing_row)
                    colors.playing
                else
                    alter[xoffset % 2];

                const qc = if (blink_queued) colors.playing else bc;

                const blinked = if (on) invert(qc) else qc;

                const color = if (uidx == self.row and self.column + 1 == xoffset) blinked else qc;

                if (val == 0xff)
                    tm.puts(x + xoffset * 2, y + yoffset, color, "..")
                else
                    tm.print(x + xoffset * 2, y + yoffset, color, "{x:0>2}", .{val});
            }

            var snapshot_color = colors.hilight2;

            if (self.upload_anim) |a| if (a.row == uidx) {
                snapshot_color = a.attrib(colors);
            };
            if (self.snapshots[uidx].active()) tm.puts(x + 8, y + yoffset, snapshot_color, "\xf0");
        }
    }

    self.blink = @mod(self.blink + dt, 1);
    self.qblink = @mod(self.qblink + dt, 1);

    if (self.upload_anim) |*a| {
        a.time -= dt;
        if (a.time == 0) self.upload_anim = null;
    }
}

inline fn invert(a: Attrib) Attrib {
    return .{ .fg = a.bg, .bg = a.fg };
}
