const MidiBuf = @import("MidiBuf.zig");
const std = @import("std");
const sdl = @import("sdl.zig");
const texture = @import("texture.zig");

const fontdata = @embedFile("assets/font.png");

const SoundEngine = @import("SoundEngine.zig");
const Self = @This();

const midi = @import("midi.zig");

var midibuf_buf: [256]midi.Event = undefined;
var midibuf = MidiBuf{ .buf = &midibuf_buf };
pub var sound_engine = SoundEngine{ .midibuf = &midibuf };

var spec: sdl.AudioSpec = undefined;
fn audiocb(data: ?*anyopaque, stream: [*c]u8, byte_len: c_int) callconv(.C) void {
    _ = data;
    const f32a = @alignOf(*Frame);
    const alt = @as([*c]align(f32a) u8, @alignCast(stream));
    const len: usize = @intCast(@divTrunc(byte_len, @sizeOf(Frame)));
    const buf = @as([*]Frame, @ptrCast(alt))[0..len];

    const srate: f32 = @floatFromInt(spec.freq);

    sound_engine.everyBuffer();

    for (buf) |*f| {
        const frame = sound_engine.next(srate);
        f.left = @min(1, @max(-1, frame.left));
        f.right = @min(1, @max(-1, frame.right));
    }
}

font: *sdl.Texture,
out: *sdl.Texture,
w: *sdl.Window,
r: *sdl.Renderer,
audio_device: sdl.AudioDeviceID,

pub fn init(title: [*:0]const u8, w_width: c_int, w_height: c_int) !Self {
    if (sdl.init(sdl.INIT_VIDEO | sdl.INIT_EVENTS | sdl.INIT_GAMECONTROLLER | sdl.INIT_AUDIO) != 0) {
        return error.FailedInitSDL;
    }
    errdefer sdl.quit();

    if (sdl.FALSE == sdl.setHint(sdl.HINT_RENDER_SCALE_QUALITY, "nearest")) return error.FailedSetScaleQuality;

    const w = sdl.createWindow(
        title,
        sdl.WINDOWPOS_UNDEFINED,
        sdl.WINDOWPOS_UNDEFINED,
        w_width * 3,
        w_height * 3,
        sdl.WINDOW_RESIZABLE,
    ) orelse
        return error.FaildeCreatingWindow;
    errdefer sdl.destroyWindow(w);

    const r = sdl.createRenderer(
        w,
        -1,
        sdl.RENDERER_ACCELERATED | sdl.RENDERER_PRESENTVSYNC,
    ) orelse
        return error.FailedCreatingRenderer;
    errdefer sdl.destroyRenderer(r);

    if (0 != sdl.renderSetLogicalSize(r, w_width, w_height)) return error.FailedSDLRenderSetLogicalSize;

    const out = sdl.createTexture(
        r,
        sdl.PIXELFORMAT_RGBA32,
        sdl.TEXTUREACCESS_TARGET,
        w_width,
        w_height,
    ) orelse
        return error.FailedCreateOutputTexture;
    errdefer sdl.destroyTexture(out);

    const font = try texture.load(r, fontdata);
    errdefer sdl.destroyTexture(font);

    const want = sdl.AudioSpec{
        .freq = 48000,
        .format = sdl.AUDIO_F32,
        .channels = 2,
        .callback = audiocb,
        .samples = 1024,
        .silence = 0,
        .padding = 0,
        .size = 0,
        .userdata = null,
    };

    const device = sdl.openAudioDevice(
        null,
        0,
        &want,
        &spec,
        sdl.AUDIO_ALLOW_FREQUENCY_CHANGE | sdl.AUDIO_ALLOW_SAMPLES_CHANGE,
    );
    if (device <= 0) return error.FailedOpenAudioDevice;
    errdefer sdl.closeAudioDevice(device);

    sdl.pauseAudioDevice(device, 0);

    _ = sdl.showCursor(sdl.DISABLE);

    return .{
        .w = w,
        .r = r,
        .font = font,
        .out = out,
        .audio_device = device,
    };
}

pub fn preRender(self: *Self) void {
    _ = sdl.setRenderTarget(self.r, null);
    _ = sdl.setRenderDrawColor(self.r, 0, 0, 0, 0xff);
    _ = sdl.renderClear(self.r);
    _ = sdl.setRenderTarget(self.r, self.out);
}

pub fn postRender(self: *Self) void {
    _ = sdl.setRenderTarget(self.r, null);
    _ = sdl.renderCopy(self.r, self.out, null, null);
    _ = sdl.renderPresent(self.r);
}

pub fn cleanup(self: *Self) void {
    sdl.closeAudioDevice(self.audio_device);
    sdl.destroyTexture(self.font);
    sdl.destroyTexture(self.out);

    sdl.destroyRenderer(self.r);
    sdl.destroyWindow(self.w);

    sdl.quit();
}

pub const Frame = packed struct {
    left: f32 = 0,
    right: f32 = 0,

    pub fn add(self: *Frame, other: Frame) void {
        self.left += other.left;
        self.right += other.right;

        self.left = @max(@min(1.0, self.left), -1.0);
        self.right = @max(@min(1.0, self.right), -1.0);
    }
};
