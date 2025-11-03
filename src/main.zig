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
const BassEditor = @import("BassEditor.zig");
const BassPattern = @import("BassPattern.zig");
const Arranger = @import("Arranger.zig");
const JoystickHandler = @import("JoystickHandler.zig");
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const PDBass = @import("PDBass.zig");
const JoyMode = @import("JoyMode.zig").JoyMode;
const save = @import("save.zig");
const MixerEditor = @import("MixerEditor.zig");
const DrumEditor = @import("DrumEditor.zig");
const MasterEditor = @import("MasterEditor.zig");
const Clipboard = @import("Clipboard.zig");

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

    var mixer_channels = true;

    var clipboard = Clipboard{};
    var bass_editor = BassEditor{ .bank = &state.bass_patterns };
    var drum_editor = DrumEditor{ .bank = &state.drum_patterns };
    var mixer_editor = MixerEditor{ .mixer = &Sys.sound_engine.mixer };

    var master_editor = MasterEditor{ .menu = &.{
        .{ .u8 = .{ .label = "master drive:  ", .ptr = &Sys.sound_engine.master_drive } },
        .{ .u8 = .{ .label = "accent diff:   ", .ptr = &Sys.sound_engine.drums.params.non_accent_level } },
        .{ .u8 = .{ .label = "duck time:     ", .ptr = &Sys.sound_engine.drums.ducker.params.time } },
        .{ .u8 = .{ .label = "delay time:    ", .ptr = &Sys.sound_engine.delay.params.time } },
        .{ .u8 = .{ .label = "delay feedback:", .ptr = &Sys.sound_engine.delay.params.feedback } },
        .{ .u8 = .{ .label = "delay duck:    ", .ptr = &Sys.sound_engine.delay.params.duck } },
        .{ .Kit = .{ .label = "drum kit:      ", .ptr = &Sys.sound_engine.drums.params.kit } },
    } };
    // .{ .Foo = .{ .label = "foo test:      ", .ptr = &foo } },

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
            &state.drum_patterns,
            &arranger,
            &Sys.sound_engine.bpm,
            &mixer_editor,
            &Sys.sound_engine.mixer,
            &Sys.sound_engine.drums.mutes,
            &Sys.sound_engine.delay.params,
            &Sys.sound_engine.drums.ducker.params,
            &Sys.sound_engine.master_drive,
            &Sys.sound_engine.drums.params.non_accent_level,
            &Sys.sound_engine.drums.params.kit,
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
                &state.drum_patterns,
                &arranger,
                Sys.sound_engine.bpm,
                &mixer_editor,
                &Sys.sound_engine.mixer,
                &Sys.sound_engine.drums.mutes,
                &Sys.sound_engine.delay.params,
                &Sys.sound_engine.drums.ducker.params,
                Sys.sound_engine.master_drive,
                Sys.sound_engine.drums.params.non_accent_level,
                Sys.sound_engine.drums.params.kit,
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
        const j_mode: JoyMode = if (trig.hold.l2)
            .res_feedback
        else if (trig.hold.r2)
            .decay_accent
        else
            .timbre_mod;

        handleParams(jh.lx, jh.ly, dt, j_mode, &Sys.sound_engine.pdbass1.params);
        handleParams(jh.rx, jh.ry, dt, j_mode, &Sys.sound_engine.pdbass2.params);

        const globalkey = trig.hold.l;

        if (globalkey) {
            if (trig.repeat.up) Sys.sound_engine.changeTempo(10);
            if (trig.repeat.down) Sys.sound_engine.changeTempo(-10);
            if (trig.repeat.left) Sys.sound_engine.changeTempo(-1);
            if (trig.repeat.right) Sys.sound_engine.changeTempo(1);
            if (trig.press.x) Sys.sound_engine.drums.mutes.toggle(.bd);
            if (trig.press.y) Sys.sound_engine.drums.mutes.toggle(.sd);
            if (trig.press.b) Sys.sound_engine.drums.mutes.toggle(.hhcy);
            if (trig.press.a) Sys.sound_engine.drums.mutes.toggle(.tm);
            if (trig.press.select and !mixer) clipboard.copy(&arranger);
            if (trig.press.start and !mixer) clipboard.paste(&arranger);
        } else {
            if (trig.comboPress("select")) mixer = !mixer;
            if (trig.comboPress("select+start")) break :mainloop;
            if (trig.comboPress("start")) Sys.sound_engine.startstop(arranger.row);
            if (Sys.sound_engine.isRunning()) tm.putch(0, 0, colors.playing, 0x10);
        }
        tm.print(1, 0, colors.normal, "{d}", .{Sys.sound_engine.getTempo()});

        const pi: []const PlaybackInfo = &[_]PlaybackInfo{
            Sys.sound_engine.bs1.playbackInfo(),
            Sys.sound_engine.bs2.playbackInfo(),
            Sys.sound_engine.ds.playbackInfo(),
        };

        const qi: []const ?u8 = &[_]?u8{
            Sys.sound_engine.bs1.queued(),
            Sys.sound_engine.bs2.queued(),
            Sys.sound_engine.ds.queued(),
        };

        if (mixer) {
            if (trig.press.r) mixer_channels = !mixer_channels;
            mixer_editor.handle(trig, mixer_channels);
            master_editor.handle(trig, !mixer_channels);
            mixer_editor.display(&tm, 1, 14, dt, mixer_channels);
            master_editor.display(&tm, 1, 1, dt, !mixer_channels);
        } else {
            if (!globalkey and trig.comboPress("r")) arrange = !arrange;
            if (arrange) {
                if (!globalkey and trig.comboPress("x")) Sys.sound_engine.enqueue(arranger.row);
                if (!globalkey) arranger.handle(trig);
                if (arranger.selectedPattern()) |p| {
                    switch (arranger.column) {
                        0, 1 => {
                            bass_editor.setPattern(p);
                            bass_editor.display(&tm, 10, 1, dt, false, pi[arranger.column]);
                        },
                        2 => {
                            drum_editor.setPattern(p);
                            drum_editor.display(
                                &tm,
                                10,
                                1,
                                dt,
                                false,
                                pi[arranger.column],
                                &Sys.sound_engine.drums.mutes,
                            );
                        },
                        else => {},
                    }
                }
                arranger.display(&tm, 1, 2, dt, true, pi, qi);
            } else {
                if (arranger.selectedPattern()) |p| {
                    switch (arranger.column) {
                        0, 1 => {
                            bass_editor.setPattern(p);
                            if (!globalkey) bass_editor.handle(trig);
                            bass_editor.display(&tm, 10, 1, dt, true, pi[arranger.column]);
                        },
                        2 => {
                            drum_editor.setPattern(p);
                            if (!globalkey) drum_editor.handle(trig);
                            drum_editor.display(
                                &tm,
                                10,
                                1,
                                dt,
                                true,
                                pi[arranger.column],
                                &Sys.sound_engine.drums.mutes,
                            );
                        },
                        else => {},
                    }
                }
                arranger.display(&tm, 1, 2, 0, false, pi, qi);
            }

            const lxy = j_mode.values(&Sys.sound_engine.pdbass1.params);
            const rxy = j_mode.values(&Sys.sound_engine.pdbass2.params);
            tm.print(1, 20, colors.inactive, "{s: <14}{x:0>2}/{x:0>2}    {x:0>2}/{x:0>2}", .{
                j_mode.str(),
                lxy.y,
                lxy.x,
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
