#!/bin/sh
# Pixel Polo: the itch.io web build, ready to upload.
#   tools/export_itch.sh [out.zip]      (default: ~/Downloads/Pixel-Polo-itch.zip)
#
# 1. Godot exports the "Web" preset (single-threaded, Compatibility, the phone fixes in its
#    head_include) into export/itch_web.
# 2. The page's <title>: Godot writes the project's config/name there, which stays "Retro Polo"
#    because it names the save folder (user:// = /userfs/godot/app_userdata/Retro Polo on the web:
#    renaming it would lose every saved career). So the title is set here, to the game's name.
# 3. The web app manifest and its two icons (the page links manifest.webmanifest) are copied in.
# 4. Everything is zipped flat: index.html at the root of the ZIP, as itch.io wants it.
# Nothing is uploaded.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
OUT="${1:-$HOME/Downloads/Pixel-Polo-itch.zip}"
WEB="$ROOT/export/itch_web"
TITLE="Pixel Polo: Water Polo Dynasty"

rm -rf "$WEB"
mkdir -p "$WEB"
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$WEB/index.html"
sed -i '' "s|<title>[^<]*</title>|<title>$TITLE</title>|" "$WEB/index.html"
cp "$ROOT/export/netlify/manifest.webmanifest" "$ROOT/export/netlify/icon-192.png" "$ROOT/export/netlify/icon-512.png" "$WEB/"
rm -f "$OUT"
(cd "$WEB" && zip -q -X -r "$OUT" .)
echo "$OUT"
unzip -l "$OUT"
