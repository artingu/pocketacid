#!/bin/bash

set -e

NAME=corrode
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

if [ ! -d zig ]; then
	# Get Zig
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
cp README.md release/$NAME-$VERSION/README.txt
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

	mkdir -p release/portmaster
	cp -rf portmaster/* release/portmaster
	cp zig-out/bin/$NAME release/portmaster/$NAME/$NAME.aarch64
	cp README.md release/portmaster/$NAME/
	mkdir release/portmaster/$NAME/licenses/
	cp README-SDL.txt release/portmaster/$NAME/licenses/
	cp README.md release/portmaster/$NAME/
	(cd release/portmaster && zip -r ../$NAME-$VERSION.portmaster.zip .)
	rm -rf release/portmaster
)
