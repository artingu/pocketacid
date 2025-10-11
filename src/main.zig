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

    var last_t = sdl.getPerformanceCounter();
    const perf_freq: f64 = @floatFromInt(sdl.getPerformanceFrequency());

    var held = ButtonState{};
    var bh = ButtonHandler{};
    var cm = ControllerManager{};
    // var drum_interface = DrumInterface{ .pattern = &state.pattern };
    var bass_interface = BassInterface{ .bank = &state.bass_patterns };

    cm.openAll();
    defer cm.closeAll();

    mainloop: while (true) {
        const current_t = sdl.getPerformanceCounter();
        const dt: f32 = @floatCast(@as(f64, @floatFromInt(current_t -% last_t)) / perf_freq);
        last_t = current_t;

        var e: sdl.Event = undefined;
        while (0 != sdl.pollEvent(&e)) {
            if (!held.handle(&e)) switch (e.type) {
                sdl.QUIT => break :mainloop,
                sdl.CONTROLLERDEVICEADDED => {
                    cm.open(e.cdevice.which);
                },
                sdl.CONTROLLERDEVICEREMOVED => {
                    cm.close(e.cdevice.which);
                },
                else => {},
            };
        }

        tm.clear(colors.normal);

        const trig = bh.handle(held, dt);
        if (trig.press.start) Sys.sound_engine.startstop();
        if (Sys.sound_engine.isRunning())
            tm.putch(0, 0, colors.playing, 0x10);
        tm.print(1, 0, colors.normal, "{d}", .{Sys.sound_engine.getTempo()});

        bass_interface.handle(trig);
        bass_interface.display(&tm, 5, 5, dt);

        sys.preRender();
        cd.flush();
        sys.postRender();
    }
}
