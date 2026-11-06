#!/bin/bash
# The "Pack Godot project" build phase in the Xcode project (added by tools/build_ios.sh). Xcode runs
# it before every build: it repacks the current game into RetroPolo.pck next to the project, so a Run
# always ships the code as it is now. If Godot can't be found the build fails instead of running a
# stale game. Set GODOT to the Godot binary if it lives somewhere else.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${SRCROOT:-$ROOT/build/ios}/RetroPolo.pck"

# Xcode runs build phases with a bare PATH, so also try the usual install locations.
GODOT_BIN="${GODOT:-}"
if [ -z "$GODOT_BIN" ]; then
	for candidate in godot /opt/homebrew/bin/godot /usr/local/bin/godot /Applications/Godot.app/Contents/MacOS/Godot; do
		if command -v "$candidate" > /dev/null 2>&1; then
			GODOT_BIN="$candidate"
			break
		fi
	done
fi
if [ -z "$GODOT_BIN" ]; then
	echo "error: Godot 4.7 not found. Install it, or set GODOT to its path." >&2
	exit 1
fi

"$GODOT_BIN" --headless --path "$ROOT/game" --export-pack "iOS" "$OUT" > /dev/null
[ -s "$OUT" ] || { echo "error: Godot did not write $OUT" >&2; exit 1; }
echo "Packed the current game into $OUT"
