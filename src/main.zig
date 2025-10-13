const std = @import("std");
const sdl = @import("sdl.zig");
const state = @import("state.zig");
const colors = @import("colors.zig");

const Sys = @import("Sys.zig");
const TextMatrix = @import("TextMatrix.zig");
const CharDisplay = @import("CharDisplay.zig");
const RGB = @import("RGB.zig");
const ButtonHandler = @import("ButtonHandler.zig");
const ControllerManager = @import("ControllerManager.zig");
const ButtonState = ButtonHandler.ButtonState;
const DrumInterface = @import("DrumInterface.zig");
const BassInterface = @import("BassInterface.zig");
const BassPattern = @import("BassPattern.zig");
const Arranger = @import("Arranger.zig");
const JoystickHandler = @import("JoystickHandler.zig");
const PlaybackInfo = @import("BassSeq.zig").PlaybackInfo;

const w = 30;
const h = 30;

pub fn main() !void {
    var sys = try Sys.init("aseq", w * 8, h * 8);
    defer sys.cleanup();

    var cells: [w * h]CharDisplay.Cell = undefined;
    var last_rendered: [w * h]CharDisplay.Cell = undefined;
    for (0..w * h) |i| last_rendered[i] = .{ .char = 0, .attrib = 0 };
    var tm = TextMatrix{ .w = w, .h = h, .out = &cells };
    const cd = CharDisplay{
        .palette = @import("palette.zig").pal,
        .w = w,
        .h = h,
        .cells = &cells,
        .last_rendered = &last_rendered,
        .out = sys.r,
        .font = sys.font,
    };

    var arrange = true;

    var last_t = sdl.getPerformanceCounter();
    const perf_freq: f64 = @floatFromInt(sdl.getPerformanceFrequency());

    var held = ButtonState{};
    var jh = JoystickHandler{};
    var bh = ButtonHandler{};
    var cm = ControllerManager{};
    var bass_interface = BassInterface{ .bank = &state.bass_patterns };

    var lj_mode: JoyMode = .timbre_mod;

    var arranger = Arranger{
        .columns = &[_]*[256]u8{
            &state.bass1_arrange,
            &state.bass2_arrange,
            &state.drum_arrange,
        },
    };

    cm.openAll();
    defer cm.closeAll();

    mainloop: while (true) {
        const current_t = sdl.getPerformanceCounter();
        const dt: f32 = @floatCast(@as(f64, @floatFromInt(current_t -% last_t)) / perf_freq);
        last_t = current_t;

        var e: sdl.Event = undefined;
        while (0 != sdl.pollEvent(&e)) {
            if (jh.handle(&e)) continue;
            if (held.handle(&e)) continue;

            switch (e.type) {
                sdl.QUIT => break :mainloop,
                sdl.CONTROLLERDEVICEADDED => {
                    cm.open(e.cdevice.which);
                },
                sdl.CONTROLLERDEVICEREMOVED => {
                    cm.close(e.cdevice.which);
                },
                else => {},
            }
        }

        tm.clear(colors.normal);

        const trig = bh.handle(held, dt);

        {
            const joy_sensitivity = 0.5;
            const lx = jh.lx * dt * joy_sensitivity;
            const ly = jh.ly * dt * joy_sensitivity;

            const lparams = &Sys.sound_engine.pdbass.params;

            switch (lj_mode) {
                .timbre_mod => {
                    const prevx = lparams.get(.mod_depth);
                    const prevy = lparams.get(.timbre);
                    lparams.set(.mod_depth, @min(1, @max(0, lx + prevx)));
                    lparams.set(.timbre, @min(1, @max(0, prevy - ly)));
                },
                .res_feedback => {
                    const prevx = lparams.get(.feedback);
                    const prevy = lparams.get(.res);
                    lparams.set(.feedback, @min(1, @max(0, lx + prevx)));
                    lparams.set(.res, @min(1, @max(0, prevy - ly)));
                },
                .decay_accent => {
                    const prevx = lparams.get(.accentness);
                    const prevy = lparams.get(.decay);
                    lparams.set(.accentness, @min(1, @max(0, lx + prevx)));
                    lparams.set(.decay, @min(1, @max(0, prevy - ly)));
                },
            }
        }

        if (trig.comboPress("l3")) lj_mode.next();
        if (trig.combo("l+up")) Sys.sound_engine.changeTempo(10);
        if (trig.combo("l+down")) Sys.sound_engine.changeTempo(-10);
        if (trig.combo("l+right")) Sys.sound_engine.changeTempo(1);
        if (trig.combo("l+left")) Sys.sound_engine.changeTempo(-1);
        if (trig.press.start) Sys.sound_engine.startstop(arranger.row);
        if (trig.press.select) arrange = !arrange;
        if (Sys.sound_engine.isRunning())
            tm.putch(0, 0, colors.playing, 0x10);
        tm.print(1, 0, colors.normal, "{d}", .{Sys.sound_engine.getTempo()});

        const pi: []const PlaybackInfo = &[_]PlaybackInfo{
            Sys.sound_engine.bs.playbackInfo(),
            PlaybackInfo{},
            PlaybackInfo{},
        };

        if (arrange) {
            arranger.handle(trig);
            if (arranger.selectedPattern()) |p| {
                bass_interface.setPattern(p);
                bass_interface.display(&tm, 10, 1, 0, false, pi[arranger.column]);
            }
            arranger.display(&tm, 1, 2, dt, true, pi);
        } else {
            if (arranger.selectedPattern()) |p| {
                bass_interface.handle(trig);
                bass_interface.setPattern(p);
                bass_interface.display(&tm, 10, 1, dt, true, pi[arranger.column]);
            }
            arranger.display(&tm, 1, 2, 0, false, pi);
        }

        tm.print(1, 19, colors.hilight, "{s}: ", .{lj_mode.str()});

        sys.preRender();
        cd.flush();
        sys.postRender();
    }
}

const JoyMode = enum {
    timbre_mod,
    res_feedback,
    decay_accent,

    fn next(self: *JoyMode) void {
        self.* = switch (self.*) {
            .timbre_mod => .res_feedback,
            .res_feedback => .decay_accent,
            .decay_accent => .timbre_mod,
        };
    }

    fn str(self: JoyMode) []const u8 {
        return switch (self) {
            .timbre_mod => "t/m",
            .res_feedback => "r/f",
            .decay_accent => "d/a",
        };
    }
};
