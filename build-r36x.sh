#!/bin/bash
export PKG_CONFIG_PATH=/home/boomlinde/src/r36xx/usr/lib/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=/home/boomlinde/src/r36xx/
exec zig build \
	-Doptimize=ReleaseFast \
	-Dtarget=aarch64-linux-gnu \
	-Dcpu=cortex_a35 \
	--search-prefix /home/boomlinde/src/r36xx/usr/
