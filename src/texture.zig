// Copyright (C) 2025  Philip Linde
//
// This file is part of Pocket Acid.
//
// Pocket Acid is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Pocket Acid is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Pocket Acid.  If not, see <https://www.gnu.org/licenses/>.

const sdl = @import("sdl.zig");
const stbi = @import("stbi.zig");

pub fn load(r: *sdl.Renderer, data: []const u8) !*sdl.Texture {
    var width: c_int = undefined;
    var height: c_int = undefined;
    const img = stbi.load_from_memory(&data[0], @intCast(data.len), &width, &height, null, 4) orelse
        return error.FailedLoadingImage;
    defer stbi.image_free(img);
    const t: *sdl.Texture = try texture_from_image(r, img, width, height);
    errdefer sdl.DestroyTexture(t);
    return t;
}
fn texture_from_image(r: *sdl.Renderer, img: *u8, width: c_int, height: c_int) !*sdl.Texture {
    const t = sdl.createTexture(r, sdl.PIXELFORMAT_ABGR8888, sdl.TEXTUREACCESS_STATIC, width, height) orelse
        return error.FailedCreatingTexture;
    errdefer sdl.destroyTexture(t);
    if (sdl.setTextureBlendMode(t, sdl.BLENDMODE_BLEND) != 0) return error.FailedSetBlendMode;
    if (sdl.updateTexture(t, null, img, 4 * width) != 0) return error.FailedSetBlendMode;
    return t;
}

test "texture" {
    _ = load;
}
