const c = @cImport({
    @cDefine("STBI_ONLY_PNG", {});
    @cDefine("STBI_NO_STDIO", {});
    @cInclude("stb_image.h");
});

pub const load_from_memory = c.stbi_load_from_memory;
pub const image_free = c.stbi_image_free;
