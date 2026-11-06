#!/bin/bash
# Exports the Web preset and packages it flat for Netlify drag-and-drop deploys:
# Godot export + manifest.webmanifest + PWA icons, zipped with index.html at the root.
# Usage: tools/export_netlify.sh [godot-binary]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${1:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
OUT="$ROOT/export/netlify"
ZIP="$ROOT/Retro_Polo_2.0_Netlify_iPhone.zip"

rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$OUT/index.html"
# the head_include script rewrites this at runtime too, but iOS home-screen launches read it at parse time
sed -i '' 's|<meta name="viewport" content="[^"]*">|<meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">|' "$OUT/index.html"
grep -q 'viewport-fit=cover' "$OUT/index.html"

sips -z 192 192 "$ROOT/game/assets/icon/ios_1024.png" --out "$OUT/icon-192.png" >/dev/null
sips -z 512 512 "$ROOT/game/assets/icon/ios_1024.png" --out "$OUT/icon-512.png" >/dev/null
cat > "$OUT/manifest.webmanifest" <<'EOF'
{
  "name": "Retro Polo",
  "short_name": "Retro Polo",
  "start_url": "./index.html",
  "scope": "./",
  "display": "fullscreen",
  "orientation": "landscape",
  "background_color": "#0f1830",
  "theme_color": "#0f1830",
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "index.apple-touch-icon.png", "sizes": "180x180", "type": "image/png" }
  ]
}
EOF
# make sure phones pick up a new build instead of a cached one
cat > "$OUT/_headers" <<'EOF'
/*
  Cache-Control: public, max-age=0, must-revalidate
/manifest.webmanifest
  Content-Type: application/manifest+json
EOF

rm -f "$ZIP"
(cd "$OUT" && zip -q -X -r "$ZIP" .)
echo "$ZIP"
