#!/bin/bash
exec zig cc -target aarch64-linux-gnu -shared -fPIC -Os -ffunction-sections -fdata-sections -Wl,--gc-sections -Wl,-soname,libSDL2-2.0.so.0 -o libSDL2.so libSDL2-stubs.c
