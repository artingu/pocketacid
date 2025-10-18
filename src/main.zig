const std = @import("std");
const sdl = @import("sdl.zig");
const state = @import("state.zig");
const colors = @import("colors.zig");

const Sys = @import("Sys.zig");
const TextMatrix = @import("TextMatrix.zig");
const CharDisplay = @import("CharDisplay.zig");
const ButtonHandler = @import("ButtonHandler.zig");
const ControllerManager = @import("ControllerManager.zig");
const ButtonState = ButtonHandler.ButtonState;
const DrumInterface = @import("DrumInterface.zig");
const BassInterface = @import("BassInterface.zig");
const BassPattern = @import("BassPattern.zig");
const Arranger = @import("Arranger.zig");
const JoystickHandler = @import("JoystickHandler.zig");
const PlaybackInfo = @import("BassSeq.zig").PlaybackInfo;
const PDBass = @import("PDBass.zig");
const JoyMode = @import("JoyMode.zig").JoyMode;
const save = @import("save.zig");
const MixerInterface = @import("MixerInterface.zig");

const w = 30;
const h = 22;
const savename = "state.sav";

pub fn main() !void {
    var cells: [w * h]CharDisplay.Cell = undefined;
    var last_rendered: [w * h]CharDisplay.Cell = undefined;
    for (0..w * h) |i| last_rendered[i] = .{ .char = 0, .attrib = .{} };
    var tm = TextMatrix{ .w = w, .h = h, .out = &cells };

    var arrange = true;
    var mixer = false;

    var last_t = sdl.getPerformanceCounter();
    const perf_freq: f64 = @floatFromInt(sdl.getPerformanceFrequency());

    var held = ButtonState{};
    var jh = JoystickHandler{};
    var bh = ButtonHandler{};
    var cm = ControllerManager{};
    var bass_interface = BassInterface{ .bank = &state.bass_patterns };

    var lj_mode: JoyMode = .timbre_mod;
    var rj_mode: JoyMode = .timbre_mod;

    var mixer_editor = MixerInterface{ .mixer = &Sys.sound_engine.mixer };

    var arranger = Arranger{
        .columns = &[_]*[256]u8{
            &state.bass1_arrange,
            &state.bass2_arrange,
            &state.drum_arrange,
        },
    };

    loadblock: {
        const cwd = std.fs.cwd();
        const file = cwd.openFile(savename, .{ .mode = .read_only }) catch |err| {
            if (err == error.FileNotFound) break :loadblock else return err;
        };
        var br = std.io.bufferedReader(file.reader());
        try save.load(
            br.reader().any(),
            &Sys.sound_engine.pdbass1.params,
            &Sys.sound_engine.pdbass2.params,
            &state.bass1_arrange,
            &state.bass2_arrange,
            &state.drum_arrange,
            &state.bass_patterns,
            &arranger,
            &Sys.sound_engine.bpm,
            &lj_mode,
            &rj_mode,
            &mixer_editor,
            &Sys.sound_engine.mixer,
        );
    }

    defer {
        saveblock: {
            const cwd = std.fs.cwd();
            const f = cwd.createFile(savename ++ ".tmp", .{}) catch break :saveblock;
            const writer = f.writer().any();

            save.save(
                writer,
                &Sys.sound_engine.pdbass1.params,
                &Sys.sound_engine.pdbass2.params,
                &state.bass1_arrange,
                &state.bass2_arrange,
                &state.drum_arrange,
                &state.bass_patterns,
                &arranger,
                Sys.sound_engine.bpm,
                lj_mode,
                rj_mode,
                &mixer_editor,
                &Sys.sound_engine.mixer,
            ) catch break :saveblock;
            cwd.rename(savename ++ ".tmp", savename) catch {};
        }
    }

    var sys = try Sys.init("aseq", w * 8, h * 8);
    defer sys.cleanup();

    const cd = CharDisplay{
        .w = w,
        .h = h,
        .cells = &cells,
        .last_rendered = &last_rendered,
        .out = sys.r,
        .font = sys.font,
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

        handleParams(jh.lx, jh.ly, dt, lj_mode, &Sys.sound_engine.pdbass1.params);
        handleParams(jh.rx, jh.ry, dt, rj_mode, &Sys.sound_engine.pdbass2.params);

        if (trig.comboPress("r")) mixer = !mixer;
        if (trig.comboPress("select+start")) break :mainloop;
        if (trig.comboPress("l3")) lj_mode.next();
        if (trig.comboPress("r3")) rj_mode.next();
        if (trig.combo("l+up")) Sys.sound_engine.changeTempo(10);
        if (trig.combo("l+down")) Sys.sound_engine.changeTempo(-10);
        if (trig.combo("l+right")) Sys.sound_engine.changeTempo(1);
        if (trig.combo("l+left")) Sys.sound_engine.changeTempo(-1);
        if (trig.comboPress("start")) Sys.sound_engine.startstop(arranger.row);
        if (Sys.sound_engine.isRunning()) tm.putch(0, 0, colors.playing, 0x10);
        tm.print(1, 0, colors.normal, "{d}", .{Sys.sound_engine.getTempo()});

        const pi: []const PlaybackInfo = &[_]PlaybackInfo{
            Sys.sound_engine.bs1.playbackInfo(),
            Sys.sound_engine.bs2.playbackInfo(),
            PlaybackInfo{},
        };

        const qi: []const ?u8 = &[_]?u8{
            Sys.sound_engine.bs1.queued(),
            Sys.sound_engine.bs2.queued(),
            null,
        };

        if (mixer) {
            mixer_editor.handle(trig);
            mixer_editor.display(&tm, 1, 1, dt);
        } else {
            if (trig.comboPress("select")) arrange = !arrange;
            if (arrange) {
                if (trig.comboPress("x")) Sys.sound_engine.enqueue(arranger.row);
                arranger.handle(trig);
                if (arranger.selectedPattern()) |p| {
                    bass_interface.setPattern(p);
                    bass_interface.display(&tm, 10, 1, 0, false, pi[arranger.column]);
                }
                arranger.display(&tm, 1, 2, dt, true, pi, qi);
            } else {
                if (arranger.selectedPattern()) |p| {
                    bass_interface.handle(trig);
                    bass_interface.setPattern(p);
                    bass_interface.display(&tm, 10, 1, dt, true, pi[arranger.column]);
                }
                arranger.display(&tm, 1, 2, 0, false, pi, qi);
            }

            const lxy = lj_mode.values(&Sys.sound_engine.pdbass1.params);
            tm.print(1, 20, colors.inactive, "{s}:{x:0>2}/{x:0>2}", .{
                lj_mode.str(),
                lxy.y,
                lxy.x,
            });

            const rxy = rj_mode.values(&Sys.sound_engine.pdbass2.params);
            tm.print(20, 20, colors.inactive, "{s}:{x:0>2}/{x:0>2}", .{
                rj_mode.str(),
                rxy.y,
                rxy.x,
            });
        }

        sys.preRender();
        cd.flush();
        sys.postRender();
    }
}

fn handleParams(ux: f32, uy: f32, dt: f32, mode: JoyMode, params: *PDBass.Params) void {
    const joy_sensitivity = 0.5;
    const x = ux * joy_sensitivity * dt;
    const y = uy * joy_sensitivity * dt;
    switch (mode) {
        .timbre_mod => {
            const prevx = params.get(.mod_depth);
            const prevy = params.get(.timbre);
            params.set(.mod_depth, @min(1, @max(0, x + prevx)));
            params.set(.timbre, @min(1, @max(0, prevy - y)));
        },
        .res_feedback => {
            const prevx = params.get(.feedback);
            const prevy = params.get(.res);
            params.set(.feedback, @min(1, @max(0, x + prevx)));
            params.set(.res, @min(1, @max(0, prevy - y)));
        },
        .decay_accent => {
            const prevx = params.get(.accentness);
            const prevy = params.get(.decay);
            params.set(.accentness, @min(1, @max(0, x + prevx)));
            params.set(.decay, @min(1, @max(0, prevy - y)));
        },
    }
}
