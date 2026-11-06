#!/bin/bash
# Builds the iPhone/iPad Bluetooth plugin (plugins/ios-ble) against Godot 4.7.2 and installs it
# into game/ios/plugins/retropolo-ble. Run on a Mac with Xcode: tools/build_ble_ios.sh
#
# Godot plugins compile against the engine's own headers, including generated ones, so this
# clones Godot 4.7.2 and starts an iOS template build just long enough to generate them (the
# same trick as Retro Swim's tools/build_storekit_ios.sh). Reuse a WORK dir to skip that step.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/plugins/ios-ble"
WORK="${WORK:-$(mktemp -d /tmp/retropolo-ble.XXXX)}"   # no spaces: Godot's scons can't handle them
GODOT_TAG=4.7.2-stable
NAME=retropolo-ble
MIN_IOS=15.6

cd "$WORK"
if [ -z "$(find godot -name 'disabled_classes.gen.h' 2>/dev/null)" ]; then
	[ -d venv ] || python3 -m venv venv
	./venv/bin/pip -q install scons
	export PATH="$WORK/venv/bin:$PATH"
	[ -d godot ] || git clone -q --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git godot
	ln -sfn "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain" "$WORK/tc"
	ln -sfn "$(xcrun --sdk iphoneos --show-sdk-path)" "$WORK/iossdk"
	(cd godot && scons platform=ios target=template_debug -j8 APPLE_TOOLCHAIN_PATH="$WORK/tc" APPLE_SDK_PATH="$WORK/iossdk" > "$WORK/scons.log" 2>&1) &
	SCONS=$!
	for _ in $(seq 1 120); do
		sleep 5
		kill -0 $SCONS 2>/dev/null || break
		[ "$(grep -c Compiling "$WORK/scons.log")" -gt 60 ] && break
	done
	pkill -f 'scons platform=ios' || true
	[ -n "$(find godot -name 'disabled_classes.gen.h')" ] || { echo "header generation failed, see $WORK/scons.log"; exit 1; }
fi

DEBUG_FLAGS="-O0 -g -DDEBUG_MEMORY_ALLOC -DDEBUG=1 -DDEBUG_ENABLED -D_DEBUG -DDISABLE_FORCED_INLINE"
RELEASE_FLAGS="-O2 -DNDEBUG -DNS_BLOCK_ASSERTIONS=1"
COMMON="-std=gnu++17 -fobjc-arc -fno-exceptions -Wall -Wno-unused-parameter -I$WORK/godot -I$WORK/godot/platform/ios"

# build <config> <sdk> <target> <flags>: one static library
build() {
	local out="$WORK/out/$1-$2"
	rm -rf "$out"
	mkdir -p "$out"
	local sysroot
	sysroot="$(xcrun --sdk "$2" --show-sdk-path)"
	for f in "$SRC"/src/*.mm; do
		xcrun --sdk "$2" clang++ -target "$3" -isysroot "$sysroot" $COMMON $4 -c "$f" -o "$out/$(basename "$f" .mm).o"
	done
	xcrun --sdk "$2" libtool -static -o "$out/lib$NAME.a" "$out"/*.o
}

for cfg in debug release; do
	flags=$DEBUG_FLAGS
	[ "$cfg" = release ] && flags=$RELEASE_FLAGS
	build "$cfg" iphoneos "arm64-apple-ios$MIN_IOS" "$flags"
	build "$cfg" iphonesimulator "arm64-apple-ios$MIN_IOS-simulator" "$flags"
	rm -rf "$WORK/out/$NAME.$cfg.xcframework"
	xcrun xcodebuild -create-xcframework \
		-library "$WORK/out/$cfg-iphoneos/lib$NAME.a" -headers "$SRC/src" \
		-library "$WORK/out/$cfg-iphonesimulator/lib$NAME.a" -headers "$SRC/src" \
		-output "$WORK/out/$NAME.$cfg.xcframework" > /dev/null
done

DEST="$ROOT/game/ios/plugins/$NAME"
rm -rf "$DEST"
mkdir -p "$DEST"
touch "$DEST/.gdignore"
cp "$SRC/$NAME.gdip" "$DEST/"
cp -R "$WORK/out/$NAME.debug.xcframework" "$WORK/out/$NAME.release.xcframework" "$DEST/"
echo "Installed game/ios/plugins/$NAME (turn on plugins/$NAME in the iOS export preset)"
