#!/bin/bash
# Build the Bluetooth LE Android plugin (plugins/android-ble) into
# game/addons/retropolo_ble/bin/retropolo-ble.aar. The editor plugin adds it to Android exports
# that use a Gradle build (see .github/workflows/build.yml, job android-ble).
#
# Needs a JDK 17+. Compiles with plain javac against:
#   - android.jar: $ANDROID_JAR, else the newest platform in $ANDROID_HOME, else Robolectric's
#     android-all jar from Maven Central (large; only for machines without an Android SDK)
#   - Godot's Android library for $GODOT_VERSION from Maven Central (or $GODOT_LIB)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$ROOT/plugins/android-ble/src/main
OUT=$ROOT/game/addons/retropolo_ble/bin
GODOT_VERSION=${GODOT_VERSION:-4.7.2}
WORK=${WORK:-$ROOT/plugins/android-ble/build}
ROBO=15-robolectric-13954326
mkdir -p "$WORK/deps" "$OUT"

fetch() {   # url dest
  [ -s "$2" ] && unzip -tq "$2" > /dev/null 2>&1 && return
  for i in 1 2 3 4; do
    curl -sSfL -o "$2" "$1" && unzip -tq "$2" > /dev/null 2>&1 && return
    sleep $((i * 2))
  done
  echo "download failed: $1" >&2
  exit 1
}

if [ -z "${ANDROID_JAR:-}" ]; then
  # newest *stable* platform (skip previews like android-37.2-beta3)
  STABLE=$(ls -d "${ANDROID_HOME:-/nonexistent}"/platforms/android-* 2>/dev/null | grep -E '/android-[0-9]+$' | sort -V | tail -1 || true)
  if [ -n "$STABLE" ] && [ -f "$STABLE/android.jar" ]; then
    ANDROID_JAR=$STABLE/android.jar
  else
    ANDROID_JAR=$WORK/deps/android-all-$ROBO.jar
    fetch "https://repo1.maven.org/maven2/org/robolectric/android-all/$ROBO/android-all-$ROBO.jar" "$ANDROID_JAR"
  fi
fi
if [ -z "${GODOT_LIB:-}" ]; then
  GODOT_LIB=$WORK/deps/godot-lib-$GODOT_VERSION.aar
  fetch "https://repo1.maven.org/maven2/org/godotengine/godot/$GODOT_VERSION.stable/godot-$GODOT_VERSION.stable.aar" "$GODOT_LIB"
fi
unzip -o -q "$GODOT_LIB" classes.jar -d "$WORK/deps/godot"
echo "android.jar: $ANDROID_JAR"
echo "godot lib:   $GODOT_LIB"

rm -rf "$WORK/classes" "$WORK/aar"
mkdir -p "$WORK/classes" "$WORK/aar"
# a quoted argfile, so a path with spaces (like this SSD's) survives
find "$SRC/java" -name '*.java' -exec printf '"%s"\n' {} \; > "$WORK/sources.txt"
javac -Xlint:all,-options,-classfile -Werror --release 17 -encoding UTF-8 \
  -cp "$ANDROID_JAR:$WORK/deps/godot/classes.jar" -d "$WORK/classes" \
  @"$WORK/sources.txt"
jar --create --no-manifest --file "$WORK/aar/classes.jar" -C "$WORK/classes" .
cp "$SRC/AndroidManifest.xml" "$WORK/aar/"
: > "$WORK/aar/R.txt"
rm -f "$OUT/retropolo-ble.aar"
jar --create --no-manifest --file "$OUT/retropolo-ble.aar" -C "$WORK/aar" .
unzip -l "$OUT/retropolo-ble.aar"
echo "built $OUT/retropolo-ble.aar"
