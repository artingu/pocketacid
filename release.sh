#!/bin/bash

set -e

NAME=cz303
VERSION="$(git describe --always)"
ZIG_VERSION=0.14.1
SDL2_WINDOWS_VERSION=2.32.6

[ ! -d prereqs ] && mkdir prereqs
[ -d release ] && rm -rf release

pushd prereqs

if [ ! -d SDL2 ]; then
	# Get SDL2 windows devel release
	wget https://github.com/libsdl-org/SDL/releases/download/release-$SDL2_WINDOWS_VERSION/SDL2-devel-$SDL2_WINDOWS_VERSION-VC.zip
	unzip SDL2-devel-$SDL2_WINDOWS_VERSION-VC.zip
	rm SDL2-devel-$SDL2_WINDOWS_VERSION-VC.zip
	mv SDL2-$SDL2_WINDOWS_VERSION SDL2
fi

# Get Zig
if [ ! -d zig ]; then
	wget https://ziglang.org/download/$ZIG_VERSION/zig-x86_64-linux-$ZIG_VERSION.tar.xz
	tar xf zig-x86_64-linux-$ZIG_VERSION.tar.xz
	rm zig-x86_64-linux-$ZIG_VERSION.tar.xz
	mv zig-x86_64-linux-$ZIG_VERSION zig
fi

popd

mkdir -p release/$NAME-$VERSION
zig build -Dcpu=core2 -Doptimize=ReleaseFast -Dtarget=x86_64-windows --verbose
cp zig-out/bin/$NAME.exe release/$NAME-$VERSION/
cp prereqs/SDL2/lib/x64/SDL2.dll release/$NAME-$VERSION/
cp prereqs/SDL2/README-SDL.txt release/$NAME-$VERSION/
zip -r release/$NAME-${VERSION}.win64.zip release/$NAME-$VERSION
rm -rf release/$NAME-$VERSION

(
	export PKG_CONFIG_PATH=$PWD/r36xx/usr/lib/pkgconfig
	export PKG_CONFIG_SYSROOT_DIR=$PWD/r36xx/
	zig build \
		-Doptimize=ReleaseFast \
		-Dtarget=aarch64-linux-gnu \
		-Dcpu=cortex_a35 \
		--search-prefix $PWD/r36xx/usr/

	mkdir -p release/$NAME-$VERSION
	cp zig-out/bin/$NAME release/$NAME-$VERSION/$NAME.aarch64
	tar czf release/$NAME-$VERSION.aarch64.tar.gz -C release $NAME-$VERSION
	rm -rf release/$NAME-$VERSION
)
