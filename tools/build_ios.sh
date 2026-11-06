#!/bin/bash
# Full iOS export: writes the Xcode project to build/ios/, adds the "Pack Godot project" build phase,
# and opens it in Xcode. The first time, pick your team under Signing & Capabilities, plug in the
# iPhone and press Run. Every Run repacks the current game first, so code changes are always
# included. Run this script again only when export settings, icons or the iOS plugins change, since
# a full export rewrites the Xcode project.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT:-godot}"

cd "$ROOT"
"$GODOT_BIN" --headless --path game --export-debug "iOS" ../build/ios/RetroPolo.ipa
python3 tools/ios_add_pack_phase.py build/ios/RetroPolo.xcodeproj/project.pbxproj
open build/ios/RetroPolo.xcodeproj
