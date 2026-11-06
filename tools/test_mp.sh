#!/bin/sh
# Two copies of the game play a multiplayer match against each other, headless, and must
# agree on the result.
#   tools/test_mp.sh            Wi-Fi (localhost)
#   tools/test_mp.sh online     through a local relay (the same protocol as relay/worker.js)
set -u
cd "$(dirname "$0")/../game" || exit 1
LINK=${1:-lan}
OUT=$(mktemp -d)
EXTRA=""
if [ "$LINK" = "online" ]; then
	godot --headless --path . -- --relay 24790 > "$OUT/relay.log" 2>&1 &
	RELAY=$!
	sleep 2
	EXTRA="--relay-url ws://127.0.0.1:24790"
fi
godot --headless --path . -- --test mp host "$LINK" 1.0 3 $EXTRA > "$OUT/host.log" 2>&1 &
H=$!
godot --headless --path . -- --test mp join "$LINK" 1.0 3 $EXTRA > "$OUT/join.log" 2>&1 &
J=$!
wait $H; HS=$?
wait $J; JS=$?
[ "$LINK" = "online" ] && kill $RELAY 2>/dev/null
echo "--- host";  grep -E "MPRES|FAIL|checks|I am|duels|SCRIPT ERROR" "$OUT/host.log"
echo "--- guest"; grep -E "MPRES|FAIL|checks|I am|duels|SCRIPT ERROR" "$OUT/join.log"
A=$(grep MPRES "$OUT/host.log")
B=$(grep MPRES "$OUT/join.log")
if [ $HS -ne 0 ] || [ $JS -ne 0 ] || [ -z "$A" ] || [ "$A" != "$B" ]; then
	echo "MULTIPLAYER TEST FAILED (logs in $OUT)"
	exit 1
fi
echo "MULTIPLAYER TEST PASSED: both phones agree"
