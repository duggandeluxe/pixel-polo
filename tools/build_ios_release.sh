#!/bin/bash
# App Store / TestFlight export (macOS + Xcode 26 or later). Writes a RELEASE Xcode project to
# build/ios-release/ and opens it; then in Xcode: pick the team, Product > Archive, Distribute App >
# App Store Connect. Unlike tools/build_ios.sh (the debug Run loop) this adds no "Pack Godot project"
# phase: the archive ships exactly what this export packed. Release builds have no developer tools
# (DevGate), use real AdMob units (Ads.PROD_UNITS) and the real App Store.
# See app_store_release/IOS_BUILD.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT:-godot}"

cd "$ROOT"
mkdir -p build/ios-release
"$GODOT_BIN" --headless --path game --export-release "iOS" ../build/ios-release/RetroPolo.ipa
open build/ios-release/RetroPolo.xcodeproj
